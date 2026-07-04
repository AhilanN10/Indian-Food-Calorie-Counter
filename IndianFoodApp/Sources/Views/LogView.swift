import SwiftUI

struct LogView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Icon + headline
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                    }
                    Text("Log a Meal")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Scan a dish or search to log calories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Backend status dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.backendOnline ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(vm.backendOnline ? "Backend connected" : "Backend offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        vm.capturedImage = nil
                        vm.showCamera    = true
                    } label: {
                        Label("Take a Photo", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(14)
                    }

                    Button {
                        vm.openBarcodeScanner()
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.85))
                            .cornerRadius(14)
                    }

                    Button {
                        vm.capturedImage    = nil
                        vm.showPhotoLibrary = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(14)
                    }

                    Button {
                        vm.openSearch()
                    } label: {
                        Label("Search Dishes", systemImage: "magnifyingglass")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
