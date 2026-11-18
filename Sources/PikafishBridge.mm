#import <Foundation/Foundation.h>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include "engine.h"
#include "position.h"
#include "search.h"

using namespace Stockfish;

static std::unique_ptr<Engine> g_engine;
static std::mutex g_mutex;
static std::condition_variable g_cv;
static std::string g_best;
static bool g_done = false;
static bool g_inited = false;

extern "C" int pf_init(const char* nnuePath, int threads, int hashMB) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_inited) return 0;

    g_engine = std::make_unique<Engine>(std::nullopt);
    g_engine->set_tt_size(hashMB);
    (void)threads; // 线程数走默认值，避免 Option API 差异

    if (nnuePath && strlen(nnuePath) > 0) {
        g_engine->load_network(std::filesystem::path(nnuePath));
    }
    g_engine->resize_threads();
    g_engine->search_clear();

    g_engine->set_on_bestmove([](std::string_view move, std::string_view /*ponder*/) {
        std::lock_guard<std::mutex> lk(g_mutex);
        g_best = std::string(move);
        g_done = true;
        g_cv.notify_all();
    });

    g_inited = true;
    return 0;
}

extern "C" char* pf_bestmove(const char* fen, int depth) {
    if (!g_engine || !fen) return strdup("");

    {
        std::lock_guard<std::mutex> lk(g_mutex);
        g_best.clear();
        g_done = false;
    }

    auto err = g_engine->set_position(std::string(fen), {});
    if (err) return strdup("");

    Search::LimitsType limits;
    limits.depth = depth;
    g_engine->go(limits);

    std::unique_lock<std::mutex> lk(g_mutex);
    g_cv.wait_for(lk, std::chrono::seconds(25), [] { return g_done; });
    return strdup(g_best.c_str());
}

extern "C" void pf_clear(void) {
    if (!g_engine) return;
    g_engine->search_clear();
}
