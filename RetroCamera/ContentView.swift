//
//  ContentView.swift
//  RetroCamera
//
//  Created by SungHyun Kim on 8/31/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedFilter: FilmFilter = .none
    @State private var grainIntensity: Double = 0.2
    
    var body: some View {
        ZStack {
            FilteredCameraView(selectedFilter: $selectedFilter, grainIntensity: $grainIntensity)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Grain intensity slider
                VStack(spacing: 5) {
                    HStack {
                        Image(systemName: "circle.grid.3x3.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Slider(value: $grainIntensity, in: 0...1) {
                            Text("Grain")
                        }
                        .accentColor(.white)
                        
                        Text("\(Int(grainIntensity * 100))%")
                            .foregroundColor(.white)
                            .font(.caption)
                            .frame(width: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Filter selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(FilmFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                                // Set default grain for each filter
                                switch filter {
                                case .none:
                                    grainIntensity = 0.0
                                case .portra400:
                                    grainIntensity = 0.12
                                case .velvia50:
                                    grainIntensity = 0.08
                                case .tri400:
                                    grainIntensity = 0.25
                                case .gold200:
                                    grainIntensity = 0.10
                                case .cinestill800T:
                                    grainIntensity = 0.30
                                case .ektachrome:
                                    grainIntensity = 0.06
                                case .fujiSuperia:
                                    grainIntensity = 0.15
                                case .kodakVision:
                                    grainIntensity = 0.18
                                case .ilfordHP5:
                                    grainIntensity = 0.35
                                case .agfaVista:
                                    grainIntensity = 0.20
                                }
                                print("Selected filter: \(filter.rawValue), grain: \(grainIntensity)")
                            }) {
                                Text(filter.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.white : Color.white.opacity(0.3))
                                    .foregroundColor(selectedFilter == filter ? .black : .white)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    ContentView()
}
