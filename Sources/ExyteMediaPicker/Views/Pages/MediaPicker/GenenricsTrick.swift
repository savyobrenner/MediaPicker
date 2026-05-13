//
//  SwiftUIView.swift
//  
//
//  Created by Alisa Mylnikova on 18.10.2023.
//

import SwiftUI

// MARK: - Partial generic specification imitation

public extension MediaPicker where AlbumSelectionContent == EmptyView {

    init(isPresented: Binding<Bool>,
         onChange: @escaping MediaPickerCompletionClosure,
         mediaTitle: String) {

        self.init(isPresented: isPresented,
                  onChange: onChange,
                  mediaTitle: mediaTitle,
                  albumSelectionBuilder: nil)
    }
}
