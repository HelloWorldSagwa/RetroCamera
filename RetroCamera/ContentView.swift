//
//  ContentView.swift
//  RetroCamera
//
//  Created by SungHyun Kim on 8/31/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedFilter: FilmFilter = .none
    @State private var grainIntensity: Double = 0.2
    @State private var lightLeakIntensity: Double = 0.0
    @State private var focusPosition: Double = 0.5
    @State private var isManualFocus: Bool = false
    @State private var bokehIntensity: Double = 0.0
    @State private var isSelectiveBokeh: Bool = true
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var shouldCapturePhoto = false
    @State private var showDateStamp: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera preview with fixed aspect ratio
            GeometryReader { geometry in
                let cameraHeight = geometry.size.width * 4 / 3
                
                VStack(spacing: 0) {
                    // Camera Preview
                    FilteredCameraView(selectedFilter: $selectedFilter,
                                     grainIntensity: $grainIntensity,
                                     lightLeakIntensity: $lightLeakIntensity,
                                     focusPosition: $focusPosition,
                                     isManualFocus: $isManualFocus,
                                     bokehIntensity: $bokehIntensity,
                                     isSelectiveBokeh: $isSelectiveBokeh,
                                     shouldCapturePhoto: $shouldCapturePhoto,
                                     capturedImage: $capturedImage,
                                     showDateStamp: $showDateStamp)
                        .frame(width: geometry.size.width, height: cameraHeight)
                        .clipped()
                    
                    // Controls Section
                    VStack(spacing: 15) {
                        // Filter selection
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(FilmFilter.allCases, id: \.self) { filter in
                                    Button(action: {
                                        selectedFilter = filter
                                        // Set default grain for each filter
                                        switch filter {
                                        case .none:
                                            grainIntensity = 0.0
                                            lightLeakIntensity = 0.0
                                        case .portra400:
                                            grainIntensity = 0.12
                                            lightLeakIntensity = 0.15
                                        case .velvia50:
                                            grainIntensity = 0.08
                                            lightLeakIntensity = 0.10
                                        case .tri400:
                                            grainIntensity = 0.25
                                            lightLeakIntensity = 0.05
                                        case .gold200:
                                            grainIntensity = 0.10
                                            lightLeakIntensity = 0.20
                                        case .cinestill800T:
                                            grainIntensity = 0.30
                                            lightLeakIntensity = 0.35
                                        case .ektachrome:
                                            grainIntensity = 0.06
                                            lightLeakIntensity = 0.12
                                        case .fujiSuperia:
                                            grainIntensity = 0.15
                                            lightLeakIntensity = 0.25
                                        case .kodakVision:
                                            grainIntensity = 0.18
                                            lightLeakIntensity = 0.08
                                        case .ilfordHP5:
                                            grainIntensity = 0.35
                                            lightLeakIntensity = 0.0
                                        case .agfaVista:
                                            grainIntensity = 0.20
                                            lightLeakIntensity = 0.30
                                        case .leicaM3Classic:
                                            grainIntensity = 0.10
                                            lightLeakIntensity = 0.18
                                        case .leicaM10Warm:
                                            grainIntensity = 0.05
                                            lightLeakIntensity = 0.12
                                        case .leicaQ2Reporter:
                                            grainIntensity = 0.15
                                            lightLeakIntensity = 0.05
                                        }
                                        print("Selected filter: \(filter.rawValue), grain: \(grainIntensity)")
                                    }) {
                                        Text(filter.rawValue)
                                            .font(.system(size: 11))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(selectedFilter == filter ? Color.white : Color.gray.opacity(0.3))
                                            .foregroundColor(selectedFilter == filter ? .black : .white)
                                            .cornerRadius(15)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        
                        // Effect controls grid
                        VStack(spacing: 8) {
                            // Manual focus control
                            HStack(spacing: 8) {
                                Button(action: {
                                    isManualFocus.toggle()
                                }) {
                                    Image(systemName: isManualFocus ? "scope" : "camera.metering.center.weighted.average")
                                        .foregroundColor(isManualFocus ? .yellow : .white)
                                        .font(.system(size: 14))
                                        .frame(width: 30)
                                }
                                
                                Slider(value: $focusPosition, in: 0...1)
                                    .accentColor(.white)
                                    .disabled(!isManualFocus)
                                    .opacity(isManualFocus ? 1.0 : 0.5)
                                
                                Text(isManualFocus ? (focusPosition < 0.3 ? "Near" : focusPosition > 0.7 ? "Far" : "Mid") : "Auto")
                                    .foregroundColor(.white)
                                    .font(.system(size: 11))
                                    .frame(width: 35)
                            }
                            
                            // Bokeh intensity slider
                            HStack(spacing: 8) {
                                Button(action: {
                                    isSelectiveBokeh.toggle()
                                }) {
                                    Image(systemName: isSelectiveBokeh ? "circle.hexagongrid.circle.fill" : "circle.hexagongrid.fill")
                                        .foregroundColor(bokehIntensity > 0 ? (isSelectiveBokeh ? .green : .yellow) : .white)
                                        .font(.system(size: 14))
                                        .frame(width: 30)
                                }
                                
                                Slider(value: $bokehIntensity, in: 0...1)
                                    .accentColor(.white)
                                
                                Text(isSelectiveBokeh ? "Spot" : "Full")
                                    .foregroundColor(.white)
                                    .font(.system(size: 11))
                                    .frame(width: 35)
                            }
                            
                            // Grain intensity slider
                            HStack(spacing: 8) {
                                Image(systemName: "circle.grid.3x3.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                                    .frame(width: 30)
                                
                                Slider(value: $grainIntensity, in: 0...1)
                                    .accentColor(.white)
                                
                                Text("\(Int(grainIntensity * 100))%")
                                    .foregroundColor(.white)
                                    .font(.system(size: 11))
                                    .frame(width: 35)
                            }
                            
                            // Light leak intensity slider
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                                    .frame(width: 30)
                                
                                Slider(value: $lightLeakIntensity, in: 0...1)
                                    .accentColor(.white)
                                
                                Text("\(Int(lightLeakIntensity * 100))%")
                                    .foregroundColor(.white)
                                    .font(.system(size: 11))
                                    .frame(width: 35)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Camera Controls (Shutter and Album buttons)
                        HStack {
                            // Album button
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            // Shutter button
                            Button(action: {
                                capturePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 65, height: 65)
                                    
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 55, height: 55)
                                }
                            }
                            
                            Spacer()
                            
                            // Date stamp toggle
                            Button(action: {
                                showDateStamp.toggle()
                            }) {
                                Image(systemName: showDateStamp ? "calendar.badge.clock" : "calendar")
                                    .font(.system(size: 24))
                                    .foregroundColor(showDateStamp ? .orange : .white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .sheet(isPresented: $showingImagePicker) {
            PhotoPicker()
        }
        .onChange(of: capturedImage) { _ in
            handleCapturedImage()
        }
    }
    
    private func capturePhoto() {
        shouldCapturePhoto = true
    }
    
    // Watch for captured image and open photo library
    private func handleCapturedImage() {
        if capturedImage != nil {
            // Automatically open photo library after capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingImagePicker = true
                capturedImage = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
