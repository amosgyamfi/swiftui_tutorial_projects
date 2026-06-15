//
//  WhatIsNewInToolbar.swift
//  SwiftUIFor27
//
//  1. .visibilityPriority(.high): Set visibility priority
//  2. ToolbarOverflowMenu {}: Specify what goes into overflow menu in the toolbar
//  3. .toolbarMinimizeBehavior(): Set a behabior for toolbar minimization
//  4. .topBarPinnedTrailing: Pin items to the trailing edge of the toolbar

import SwiftUI

struct WhatIsNewInToolbar: View {
    var body: some View {
        NavigationStack {
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(1...30, id: \.self) { index in
                        Label("Sticker \(index)", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("Sticker List")
            .toolbar {
                ToolbarItemGroup {
                    
                    Button {
                        //
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    
                    Button {
                        //
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    
                    Button {
                        //
                    } label: {
                        Image(systemName: "eraser")
                    }
                    
                    // Show overflow
                    /*Button {
                     //
                     } label: {
                     Image(systemName: "xmark")
                     }
                     
                     Button {
                     //
                     } label: {
                     Image(systemName: "document.on.document")
                     }*/
                }
                // 1. Set visibility priority
                //.visibilityPriority(.high)
                
                // 2. Specify what goes into overflow menu
                /*ToolbarOverflowMenu {
                 
                 }*/
                
                // 4. topBarPinnedTrailing: Pin items to the trailing edge of the toolbar
                /*ToolbarItemGroup(placement: .topBarPinnedTrailing) {
                 Button {
                 //
                 } label: {
                 Image(systemName: "xmark")
                 }
                 
                 Button {
                 //
                 } label: {
                 Image(systemName: "document.on.document")
                 }
                 }*/
                
                ToolbarItemGroup {
                    Button {
                        //
                    } label: {
                        Image(systemName: "pencil.and.ruler")
                    }
                    
                    Button {
                        //
                    } label: {
                        Image(systemName: "pencil.and.outline")
                    }
                    
                    Button {
                        //
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            // 3. Set the behabior for toolbar minimization
            //.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
        }
    }
}

#Preview {
    WhatIsNewInToolbar()
}
