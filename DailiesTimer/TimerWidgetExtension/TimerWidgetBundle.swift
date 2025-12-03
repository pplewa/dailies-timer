import WidgetKit
import SwiftUI

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        TimerLiveActivity()
        if #available(iOS 18.0, *) {
            TimerControlWidget()
        }
    }
}
