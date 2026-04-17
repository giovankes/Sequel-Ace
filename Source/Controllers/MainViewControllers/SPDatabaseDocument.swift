//
//  SPDatabaseDocument.swift
//  Sequel Ace
//
//  Created by Jakub Kašpar on 11.03.2021.
//  Copyright © 2020-2022 Sequel-Ace. All rights reserved.
//

import AppKit

@objcMembers
final class SPClickHouseSupport: NSObject {
    private static func backtickQuotedIdentifier(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "`", with: "``")
        return "`\(escapedValue)`"
    }

    private static func tickQuotedLiteral(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "'\(escapedValue)'"
    }

    @objc(columnMetadataQueryWithTableName:databaseName:isClickHouse:)
    static func columnMetadataQuery(tableName: String, databaseName: String?, isClickHouse: Bool) -> String {
        if !isClickHouse {
            if let databaseName, !databaseName.isEmpty {
                let quotedDatabaseName = backtickQuotedIdentifier(databaseName)
                let quotedTableName = backtickQuotedIdentifier(tableName)
                return "SHOW COLUMNS FROM \(quotedDatabaseName).\(quotedTableName)"
            }

            return "SHOW COLUMNS FROM \(backtickQuotedIdentifier(tableName))"
        }

        let resolvedDatabaseName = databaseName ?? ""
        let quotedDatabaseName = tickQuotedLiteral(resolvedDatabaseName)
        let quotedTableName = tickQuotedLiteral(tableName)

        return """
        SELECT name AS Field, \
        type AS Type, \
        if(startsWith(type, 'Nullable('), 'YES', 'NO') AS `Null`, \
        if(is_in_primary_key = 1, 'PRI', '') AS `Key`, \
        default_expression AS `Default`, \
        '' AS Extra \
        FROM system.columns \
        WHERE database = \(quotedDatabaseName) AND table = \(quotedTableName) \
        ORDER BY position
        """
    }

    @objc(shouldDisableDatabaseDocumentMenuActionForClickHouse:)
    static func shouldDisableDatabaseDocumentMenuActionForClickHouse(_ action: Selector) -> Bool {
        let disabledViewActions: Set<String> = [
            "viewStructure",
            "viewRelations",
            "viewStatus",
            "viewTriggers",
        ]

        let disabledTableActions: Set<String> = [
            "analyzeTable:",
            "optimizeTable:",
            "repairTable:",
            "flushTable:",
            "checkTable:",
            "checksumTable:",
            "showUserManager",
        ]

        let actionName = NSStringFromSelector(action)
        return disabledViewActions.contains(actionName) || disabledTableActions.contains(actionName)
    }

    @objc(shouldDisableTablesListMenuActionForClickHouse:)
    static func shouldDisableTablesListMenuActionForClickHouse(_ action: Selector) -> Bool {
        let disabledActions: Set<String> = [
            "addTable:",
            "copyTable:",
            "renameTable:",
            "removeTable:",
            "truncateTable:",
        ]

        return disabledActions.contains(NSStringFromSelector(action))
    }
}

extension SPDatabaseDocument {
    @objc func prepareSaveAccessoryView(panel: NSSavePanel) {
        guard Bundle.main.loadNibNamed("SaveSPFAccessory", owner: self, topLevelObjects: nil) else {
            Swift.print("❌ SaveSPFAccessory accessory dialog could not be loaded.")
            return
        }

        guard let appDelegate = NSApp.delegate as? SPAppController else {
            return
        }

        let sessionData = appDelegate.spfSessionDocData()

        // Restore accessory view settings if possible
        if let save_password = sessionData?["save_password"] as? Bool {
            saveConnectionSavePassword.state = save_password ? .on : .off
        }
        if let auto_connect = sessionData?["auto_connect"] as? Bool {
            saveConnectionAutoConnect.state = auto_connect ? .on : .off
        }
        if let encrypted = sessionData?["encrypted"] as? Bool {
            saveConnectionEncrypt.state = encrypted ? .on : .off
        }
        if let include_session = sessionData?["include_session"] as? Bool {
            saveConnectionIncludeData.state = include_session ? .on : .off
        }
        if let save_editor_content = sessionData?["save_editor_content"] as? Bool {
            saveConnectionIncludeQuery.state = save_editor_content ? .on : .off
        } else {
            saveConnectionIncludeQuery.state = .on
        }
    }
}
