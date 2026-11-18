import Foundation
import SQLite3

/// 开局库读取器：bh.obk 实际是 SQLite 数据库（表 bhobk，10.6 万条记录）。
/// 表结构：id, vkey(局面哈希), vmove(着法编码), vscore, vwin, vdraw, vlost, vvalid, vmemo, vindex
final class OpeningBook {
    static let shared = OpeningBook()

    private var db: OpaquePointer?
    private(set) var recordCount: Int = 0

    private init() {}

    func open() {
        guard db == nil else { return }
        guard let path = Bundle.main.path(forResource: "bh", ofType: "obk") else {
            NSLog("[OpeningBook] bh.obk not found")
            return
        }
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            NSLog("[OpeningBook] open failed: %@", String(cString: sqlite3_errmsg(db)))
            if db != nil { sqlite3_close(db); db = nil }
            return
        }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM bhobk", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                recordCount = Int(sqlite3_column_int64(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }
        NSLog("[OpeningBook] loaded %d records", recordCount)
    }

    /// 取评分最高的若干条，用于验证库可读
    func topEntries(limit: Int = 5) -> [(key: Int64, move: Int64, score: Int, win: Int, draw: Int, lost: Int)] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        var result: [(Int64, Int64, Int, Int, Int, Int)] = []
        let sql = "SELECT vkey, vmove, vscore, vwin, vdraw, vlost FROM bhobk WHERE vvalid=1 ORDER BY vscore DESC LIMIT ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append((sqlite3_column_int64(stmt, 0),
                           sqlite3_column_int64(stmt, 1),
                           Int(sqlite3_column_int(stmt, 2)),
                           Int(sqlite3_column_int(stmt, 3)),
                           Int(sqlite3_column_int(stmt, 4)),
                           Int(sqlite3_column_int(stmt, 5))))
        }
        sqlite3_finalize(stmt)
        return result
    }

    func summary() -> String {
        guard recordCount > 0 else { return "开局库未加载" }
        let top = topEntries(limit: 3)
        let head = top.map { "score \($0.score) · \($0.win)/\($0.draw)/\($0.lost)" }.joined(separator: "  ")
        return "开局库 \(recordCount) 条｜\(head)"
    }
}
