//
//  L10n.swift
//  Newton
//
//  Created for Newton iOS.
//  Uniform type-safe localization without ternaries or nil-coalescing.
//

import Foundation
import SwiftUI

public enum L10n {
    public static func tr(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    public static var all: String { tr("All") }
    public static var chats: String { tr("Chats") }
    public static var remoteStudio: String { tr("Remote Studio") }
    public static var hostOnline: String { tr("Host Online") }
    public static var hostOffline: String { tr("Host Offline") }
    public static var hostConnected: String { tr("Mac Host Conectado") }
    public static var hostDisconnected: String { tr("Mac Host Desconectado") }
    public static var ghostSession: String { tr("Ghost Session") }
    public static var artGallery: String { tr("Art gallery") }
    public static var recents: String { tr("Recents") }
    public static var remoteStudioTasks: String { tr("Remote Studio Tasks") }
    public static var pinnedHeader: String { tr("FIJADOS") }
    public static var recentsHeader: String { tr("RECIENTES") }
    public static var conversationsHeader: String { tr("CONVERSACIONES") }
    public static var newChat: String { tr("New chat") }
    public static var pin: String { tr("Pin") }
    public static var unpin: String { tr("Unpin") }
    public static var delete: String { tr("Delete") }
    public static var pinChat: String { tr("Pin Chat") }
    public static var unpinChat: String { tr("Unpin Chat") }
    public static var deleteChat: String { tr("Delete Chat") }
    public static var cancel: String { tr("Cancel") }
    public static var selectWorkspaceForNewTask: String { tr("Seleccionar Workspace para Nueva Tarea") }
    public static var openTaskInWorkspace: String { tr("Abrir Tarea en Workspace") }
    public static var remoteCodeTask: String { tr("Remote Code Task") }
}

extension LocalizedStringKey {
    public static let newChat = LocalizedStringKey("New chat")
    public static let remoteStudio = LocalizedStringKey("Remote Studio")
    public static let all = LocalizedStringKey("All")
    public static let chats = LocalizedStringKey("Chats")
}
