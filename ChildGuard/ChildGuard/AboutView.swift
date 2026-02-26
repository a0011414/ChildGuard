//
//  AboutView.swift
//  ChildGuard
//
//  このアプリについて：免責・利用上の注意
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("親子で決めたルールに従い、利用時間の制限や通知を行うためのアプリです。ルールはアプリ内で設定・保存し、その内容に沿って動作します。")
                    .font(.body)
            } header: {
                Text("このアプリについて")
            }

            Section {
                Text("・本アプリの利用により生じた不都合や損害について、開発者は一切の責任を負いません。利用は自己責任でお願いします。")
                Text("・本アプリは現状のまま提供され、動作や結果について保証するものではありません。")
            } header: {
                Text("免責事項")
            }

            Section {
                Text("・ルールは親子で話し合って決め、アプリはそのルールを補助的に守るための道具としてお使いください。")
                Text("・制限や通知の内容は、ご利用の端末やOSの仕様により変わる場合があります。")
            } header: {
                Text("利用上の注意")
            }
        }
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
