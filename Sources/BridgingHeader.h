#ifndef BridgingHeader_h
#define BridgingHeader_h

#include <stdlib.h>

/// 初始化 Pikafish 引擎（nnuePath 为包内 pikafish.nnue 的绝对路径）
int pf_init(const char* nnuePath, int threads, int hashMB);

/// 同步求解最佳着法，返回 malloc 的字符串，调用方需 free
char* pf_bestmove(const char* fen, int depth);

/// 清空搜索状态
void pf_clear(void);

#endif /* BridgingHeader_h */
