//
//  IndicatorSelectionView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

// Wrapper to make any Indicator work with Identifiable requirements
struct IdentifiableIndicator: Identifiable {
    let id = UUID()
    let indicator: any Indicator
    
    init(_ indicator: any Indicator) {
        self.indicator = indicator
    }
}

struct IndicatorSelectionView: View {
    @ObservedObject var viewModel: ChartViewModel
    @Environment(\.dismiss) var dismiss
    
    // State for potentially editing an indicator (e.g., changing color or period)
    @State private var editingIndicator: IdentifiableIndicator? = nil
    @State private var selectedColor: Color = .blue // Default color for editing

    var body: some View {
        NavigationView {
            List {
                Section("Available Indicators") {
                    // Predefined indicators
                    Button("Add SMA (20, Orange)") {
                        viewModel.addSampleIndicator(type: "SMA")
                    }
                    Button("Add SMA (50, Red)") {
                        viewModel.addSampleIndicator(type: "SMA_50_RED")
                    }
                    Button("Add NWOG (Demo, Purple)") {
                        viewModel.addSampleIndicator(type: "NWOG")
                    }
                    // TODO: Add section for Lua script based indicators
                    // Button("Add Indicator from Lua Script") { /* show Lua script picker */ }
                    
                    Button("Add Lua SMA (10, Green) - Simulated") {
                        let luaSMAScript = """
                        -- Simple SMA Indicator in Lua (simulated)
                        -- name = \"Lua SMA(10)\"
                        -- period = 10
                        
                        function calculate(ohlc)
                            local sma_values = {}
                            local period = 10 -- This should ideally be configurable
                            if #ohlc < period then return sma_values end
                            
                            for i = period, #ohlc do
                                local sum = 0
                                for j = i - period + 1, i do
                                    sum = sum + ohlc[j].close
                                end
                                table.insert(sma_values, sum / period)
                            end
                            return sma_values
                        end
                        """
                        let luaIndicator = LuaIndicator(name: "Lua SMA(10)", scriptContent: luaSMAScript, color: .green)
                        viewModel.indicatorManager.addIndicator(luaIndicator, ohlcData: viewModel.ohlcData)
                    }
                    
                    Button("Add Lua DoubleClose (Cyan) - Simulated") {
                        let luaDoubleCloseScript = """
                        -- Doubles the close price (simulated)
                        -- name = \"Lua DoubleClose\"
                        function calculate(ohlc)
                            local results = {}
                            for i = 1, #ohlc do
                                table.insert(results, ohlc[i].close * 2)
                            end
                            return results
                        end
                        """
                        let luaIndicator = LuaIndicator(name: "Lua DoubleClose", scriptContent: luaDoubleCloseScript, color: .cyan)
                        viewModel.indicatorManager.addIndicator(luaIndicator, ohlcData: viewModel.ohlcData)
                    }
                }

                Section("Active Indicators") {
                    if viewModel.indicatorManager.activeIndicators.isEmpty {
                        Text("No active indicators.").foregroundColor(.gray)
                    }
                    ForEach(viewModel.indicatorManager.activeIndicators, id: \.id) { indicator in
                        HStack {
                            Text(indicator.name)
                            Spacer()
                            Circle()
                                .fill(indicator.color)
                                .frame(width: 15, height: 15)
                                .onTapGesture {
                                    self.editingIndicator = IdentifiableIndicator(indicator)
                                    self.selectedColor = indicator.color
                                }
                            Button {
                                viewModel.removeIndicator(indicator)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Indicators")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingIndicator) { indicatorToEdit in
                // Simple color picker sheet for demonstration
                // A more complex editor could be presented for period, etc.
                VStack {
                    Text("Edit Indicator: \(indicatorToEdit)")
                        .font(.headline)
                        .padding()
                    
                    ColorPicker("Select Color", selection: $selectedColor)
                        .padding()
                    
                    Button("Apply") {
                        viewModel.updateIndicatorColor(indicatorId: indicatorToEdit.id, newColor: selectedColor)
                        editingIndicator = nil // Dismiss sheet
                    }
                    .padding()
                    
                    Button("Cancel") {
                        editingIndicator = nil // Dismiss sheet
                    }
                    .padding()
                    Spacer()
                }
            }
        }
    }
}

// Preview provider for IndicatorSelectionView
struct IndicatorSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy ChartViewModel for previewing purposes
        let dummyViewModel = ChartViewModel()
        // Add a sample indicator to the dummy view model for preview
        dummyViewModel.addSampleIndicator(type: "SMA")
        
        return IndicatorSelectionView(viewModel: dummyViewModel)
    }
}
