//
//  Created by Alex.M on 09.06.2022.
//
//  Fullscreen viewer modeled after the iOS 26 Photos preview:
//  - Pure black background.
//  - Top chrome (Done button + selection badge) and a bottom chrome
//    (asset date/time) that toggle on tap, just like Photos.
//  - Swipe horizontally to navigate between assets.
//  - Drag down to dismiss (interactive, like the native dismiss).
//  - Pinch-to-zoom is preserved by the underlying FullscreenCell.
//

import Foundation
import SwiftUI

struct FullscreenContainer: View {

    @EnvironmentObject private var selectionService: SelectionService
    @Environment(\.mediaPickerTheme) private var theme

    @ObservedObject var keyboardHeightHelper = KeyboardHeightHelper.shared

    @Binding var isPresented: Bool
    @Binding var currentFullscreenMedia: Media?
    let assetMediaModels: [AssetMediaModel]
    @State var selection: AssetMediaModel.ID
    var selectionParamsHolder: SelectionParamsHolder
    var shouldDismiss: ()->()

    @State private var showsChrome: Bool = true
    @GestureState private var dragOffset: CGSize = .zero

    private var selectedMediaModel: AssetMediaModel? {
        assetMediaModels.first { $0.id == selection }
    }

    private var selectionServiceIndex: Int? {
        guard let selectedMediaModel = selectedMediaModel else { return nil }
        return selectionService.index(of: selectedMediaModel)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selection) {
                ForEach(assetMediaModels, id: \.id) { assetMediaModel in
                    FullscreenCell(viewModel: FullscreenCellViewModel(mediaModel: assetMediaModel))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(assetMediaModel.id)
                        .onTapGesture {
                            if keyboardHeightHelper.keyboardDisplayed {
                                dismissKeyboard()
                            } else {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    showsChrome.toggle()
                                }
                            }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: max(dragOffset.height, 0))
            .opacity(dismissOpacity)
            
            chrome
                .opacity(showsChrome ? 1 : 0)
        }
        .onChange(of: selection) { _ in
            if let selectedMediaModel {
                currentFullscreenMedia = Media(source: selectedMediaModel)
            }
        }
        .simultaneousGesture(verticalDismissGesture)
    }
    
    // MARK: - Chrome (top + bottom)
    
    private var chrome: some View {
        VStack {
            topBar
            Spacer()
            bottomBar
        }
    }
    
    private var topBar: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Text(localized("Concluído", "Done"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            
            Spacer()
            
            if let selectedMediaModel = selectedMediaModel {
                if selectionParamsHolder.selectionLimit == 1 {
                    Button {
                        selectionService.onSelect(assetMediaModel: selectedMediaModel)
                        shouldDismiss()
                    } label: {
                        Text(localized("Selecionar", "Select"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                } else {
                    Button {
                        selectionService.onSelect(assetMediaModel: selectedMediaModel)
                    } label: {
                        selectionTopBadge(model: selectedMediaModel)
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.top, 4)
        .background(LinearGradient(
            colors: [.black.opacity(0.6), .clear],
            startPoint: .top,
            endPoint: .bottom
        ))
    }
    
    @ViewBuilder
    private func selectionTopBadge(model: AssetMediaModel) -> some View {
        if let index = selectionService.index(of: model) {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.selection.selectedTint))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
        } else if selectionService.canSelect(assetMediaModel: model) {
            Circle()
                .stroke(.white, lineWidth: 1.5)
                .background(Circle().fill(.black.opacity(0.25)))
                .frame(width: 28, height: 28)
        }
    }
    
    private var bottomBar: some View {
        Group {
            if let model = selectedMediaModel,
               let date = model.asset.creationDate {
                VStack(spacing: 2) {
                    Text(dayTitle(for: date))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(timeFormatter.string(from: date))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            } else {
                Color.clear.frame(height: 1)
            }
        }
    }
    
    // MARK: - Drag-to-dismiss
    
    private var verticalDismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                if value.translation.height > 140 {
                    isPresented = false
                }
            }
    }
    
    private var dismissOpacity: Double {
        let progress = max(0, dragOffset.height) / 400
        return 1 - min(progress, 0.6)
    }
    
    // MARK: - Formatting
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        f.locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")
        f.timeStyle = .short
        return f
    }
    
    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        if calendar.isDateInToday(date) {
            return isPortuguese ? "Hoje" : "Today"
        } else if calendar.isDateInYesterday(date) {
            return isPortuguese ? "Ontem" : "Yesterday"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")
        f.setLocalizedDateFormatFromTemplate(isPortuguese ? "d 'de' MMMM yyyy" : "MMMM d, yyyy")
        return f.string(from: date)
    }
    
    private func localized(_ ptBR: String, _ enUS: String) -> String {
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        return isPortuguese ? ptBR : enUS
    }
}
