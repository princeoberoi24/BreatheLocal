//
//  ContentView.swift
//  BreatheLocal
//
//  Created by Apple on 24/09/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = StorageViewModel()

    var body: some View {
        DashboardView()
            .environment(viewModel)
            .tint(.sageGreen)
    }
}

#Preview {
    ContentView()
}
