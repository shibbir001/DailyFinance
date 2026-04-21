//
//  DailyFinanceWidgetLiveActivity.swift
//  DailyFinanceWidget
//
//  Created by Shibbir on 21/3/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DailyFinanceWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DailyFinanceWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyFinanceWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DailyFinanceWidgetAttributes {
    fileprivate static var preview: DailyFinanceWidgetAttributes {
        DailyFinanceWidgetAttributes(name: "World")
    }
}

extension DailyFinanceWidgetAttributes.ContentState {
    fileprivate static var smiley: DailyFinanceWidgetAttributes.ContentState {
        DailyFinanceWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DailyFinanceWidgetAttributes.ContentState {
         DailyFinanceWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DailyFinanceWidgetAttributes.preview) {
   DailyFinanceWidgetLiveActivity()
} contentStates: {
    DailyFinanceWidgetAttributes.ContentState.smiley
    DailyFinanceWidgetAttributes.ContentState.starEyes
}
