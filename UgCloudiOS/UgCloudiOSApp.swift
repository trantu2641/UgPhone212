import SwiftUI

@main
struct UgCloudiOSApp: App {
    @StateObject private var store = DeviceStore()
    var body: some Scene {
        WindowGroup { MainView().environmentObject(store).preferredColorScheme(.dark) }
    }
}

struct CloudDevice: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var endpoint: String
    var status: String = "Chưa kết nối"
    var autoReconnect: Bool = true
    var note: String = "Thêm địa chỉ máy chủ điều khiển của bạn"
}

@MainActor final class DeviceStore: ObservableObject {
    @Published var devices: [CloudDevice] = [] { didSet { save() } }
    private let key = "ugcloud.devices.v1"
    init() {
        if let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode([CloudDevice].self, from: data) { devices = saved }
        if devices.isEmpty {
            devices = [CloudDevice(name: "Android của tôi", endpoint: "", note: "Mẫu thiết bị • chưa cấu hình kết nối")]
        }
    }
    func save() { if let data = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(data, forKey: key) } }
    func add(name: String, endpoint: String) { devices.append(CloudDevice(name: name, endpoint: endpoint)) }
    func update(_ device: CloudDevice) { if let i = devices.firstIndex(where: {$0.id == device.id}) { devices[i] = device } }
    func remove(at offsets: IndexSet) { devices.remove(atOffsets: offsets) }
}

struct MainView: View {
    @EnvironmentObject var store: DeviceStore
    var body: some View {
        TabView {
            DeviceListView().tabItem { Label("Thiết bị", systemImage: "iphone.gen3") }
            CloudView().tabItem { Label("Cloud", systemImage: "cloud.fill") }
            FilesView().tabItem { Label("Tệp APK", systemImage: "folder.fill") }
            SettingsView().tabItem { Label("Cài đặt", systemImage: "gearshape.fill") }
        }.tint(.cyan)
    }
}

struct DeviceListView: View {
    @EnvironmentObject var store: DeviceStore
    @State private var showingAdd = false
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.035, green: 0.055, blue: 0.09).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("UG CLOUD").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(3).foregroundStyle(.cyan)
                                Text("Thiết bị của bạn").font(.system(size: 29, weight: .bold, design: .rounded))
                                Text("Quản lý tập trung • kết nối từ xa").font(.subheadline).foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                            Image(systemName: "cloud.fill").font(.system(size: 30)).foregroundStyle(.cyan)
                        }.padding(.top, 14)
                        Button { showingAdd = true } label: {
                            Label("Thêm thiết bị", systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                        }.buttonStyle(.borderedProminent).tint(.cyan).foregroundStyle(.black)
                        ForEach(store.devices) { device in
                            NavigationLink { DeviceDetailView(deviceID: device.id) } label: { DeviceCard(device: device) }.buttonStyle(.plain)
                        }.onDelete(perform: store.remove)
                        Text("Lưu ý: hiện đây là giao diện nền tảng. Kết nối thật cần dịch vụ Android/Cloud có API và thông tin xác thực tương thích.")
                            .font(.caption).foregroundStyle(.white.opacity(0.45)).padding(.top, 4)
                    }.padding(20)
                }
            }.toolbar(.hidden, for: .navigationBar).sheet(isPresented: $showingAdd) { AddDeviceView() }
        }
    }
}

struct DeviceCard: View {
    let device: CloudDevice
    var body: some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 16).fill(Color.cyan.opacity(0.13)); Image(systemName: "iphone.gen3").font(.system(size: 25)).foregroundStyle(.cyan) }.frame(width: 58, height: 66)
            VStack(alignment: .leading, spacing: 5) {
                Text(device.name).font(.headline).foregroundStyle(.white)
                Text(device.endpoint.isEmpty ? "Chưa cấu hình máy chủ" : device.endpoint).font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                Label(device.status, systemImage: "circle.fill").font(.caption2).foregroundStyle(.orange)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.35))
        }.padding(14).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07)))
    }
}

struct AddDeviceView: View {
    @EnvironmentObject var store: DeviceStore
    @Environment(\.dismiss) var dismiss
    @State private var name = "Android mới"
    @State private var endpoint = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin thiết bị") {
                    TextField("Tên dễ nhớ", text: $name)
                    TextField("Địa chỉ API / máy chủ", text: $endpoint).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                }
                Section { Text("Chỉ nhập endpoint của máy chủ bạn sở hữu hoặc được phép sử dụng. Chưa thể kết nối UgPhone chỉ bằng cách đoán địa chỉ API.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Thêm thiết bị").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Lưu") { store.add(name: name.isEmpty ? "Android mới" : name, endpoint: endpoint); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }.preferredColorScheme(.dark)
    }
}

struct DeviceDetailView: View {
    @EnvironmentObject var store: DeviceStore
    let deviceID: UUID
    @State private var showConnectInfo = false
    private var device: CloudDevice { store.devices.first(where: {$0.id == deviceID}) ?? CloudDevice(name: "Thiết bị", endpoint: "") }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(Color.black).overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                    VStack(spacing: 14) { Image(systemName: "display.and.arrow.down").font(.system(size: 44)).foregroundStyle(.cyan); Text("Màn hình Android").font(.title3.bold()); Text("Luồng hình ảnh sẽ xuất hiện tại đây khi backend streaming được cấu hình.").multilineTextAlignment(.center).font(.footnote).foregroundStyle(.white.opacity(0.55)).padding(.horizontal, 20) }
                }.frame(height: 330)
                Button { showConnectInfo = true } label: { Label("Kết nối thiết bị", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity).padding(14) }.buttonStyle(.borderedProminent).tint(.cyan).foregroundStyle(.black)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ActionTile(icon: "hand.tap", title: "Điều khiển", subtitle: "Chạm / vuốt")
                    ActionTile(icon: "keyboard", title: "Bàn phím", subtitle: "Nhập văn bản")
                    ActionTile(icon: "arrow.clockwise", title: "Khởi động lại", subtitle: "Cần API thiết bị")
                    ActionTile(icon: "square.stack.3d.up", title: "Ứng dụng", subtitle: "Cần quyền quản trị")
                }
                Toggle("Tự kết nối lại", isOn: Binding(get: { device.autoReconnect }, set: { var d = device; d.autoReconnect = $0; store.update(d) })).padding(16).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                Text("Các nút điều khiển hiện là khung giao diện, chưa gửi lệnh đến thiết bị.").font(.caption).foregroundStyle(.secondary)
            }.padding(18)
        }.background(Color(red: 0.035, green: 0.055, blue: 0.09)).navigationTitle(device.name).navigationBarTitleDisplayMode(.inline).alert("Chưa có kết nối backend", isPresented: $showConnectInfo) { Button("Đóng", role: .cancel) {} } message: { Text("Cần endpoint API, cơ chế đăng nhập và giao thức truyền màn hình của máy chủ hợp lệ trước khi bật kết nối thật.") }
    }
}

struct ActionTile: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View { VStack(alignment: .leading, spacing: 9) { Image(systemName: icon).font(.title2).foregroundStyle(.cyan); Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.5)) }.frame(maxWidth: .infinity, minHeight: 94, alignment: .leading).padding(14).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18)) }
}

struct CloudView: View {
    var body: some View { NavigationStack { List {
        Section { Label("Khởi chạy Android trên đám mây", systemImage: "cloud.fill").font(.headline); Text("Để tạo máy ảo/cloud phone thật, cần nhà cung cấp hoặc cụm máy chủ Android, API cấp phát phiên, xác thực và thanh toán.").font(.footnote).foregroundStyle(.secondary) }
        Section("Các bước tích hợp") { Label("Chọn nhà cung cấp hoặc tự host", systemImage: "server.rack"); Label("Tích hợp API tạo / dừng máy", systemImage: "play.rectangle"); Label("Nhận thông tin stream và kết nối", systemImage: "dot.radiowaves.left.and.right") }
    }.navigationTitle("Cloud Phone") }.preferredColorScheme(.dark) }
}

struct FilesView: View {
    @State private var showingPicker = false
    @State private var selectedName: String?
    var body: some View { NavigationStack { VStack(spacing: 18) {
        Image(systemName: "shippingbox.fill").font(.system(size: 46)).foregroundStyle(.cyan)
        Text("Quản lý APK").font(.title2.bold())
        Text("Chọn tệp APK từ ứng dụng Tệp để chuẩn bị chuyển lên thiết bị Android khi kết nối truyền tệp được tích hợp.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
        Button { showingPicker = true } label: { Label("Chọn tệp APK", systemImage: "folder.badge.plus").frame(maxWidth: .infinity).padding(14) }.buttonStyle(.borderedProminent).tint(.cyan).foregroundStyle(.black).padding(.horizontal)
        if let selectedName { Label("Đã chọn: \(selectedName)", systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.green).padding(.horizontal) }
        Text("iOS không thể cài APK trực tiếp. Tệp cần được chuyển tới Android và cài bằng cơ chế được thiết bị cho phép.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24)
        Spacer()
    }.padding(.top, 40).navigationTitle("Tệp & APK") }.fileImporter(isPresented: $showingPicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
        if case .success(let urls) = result { selectedName = urls.first?.lastPathComponent }
    }.preferredColorScheme(.dark) }
}

struct SettingsView: View {
    var body: some View { NavigationStack { List {
        Section("Ứng dụng") { LabeledContent("Tên", value: "UG Cloud iOS"); LabeledContent("Phiên bản", value: "0.1.0 • Prototype") }
        Section("Bảo mật") { Label("Không nhúng mật khẩu hay token vào mã nguồn", systemImage: "lock.shield"); Label("Chỉ kết nối máy chủ HTTPS/WSS đáng tin cậy", systemImage: "checkmark.shield") }
        Section("Tình trạng") { Text("Chưa có backend API, thông tin xác thực UgPhone hoặc chứng thư ký IPA. Đây là bản khung giao diện để phát triển tiếp.").font(.footnote).foregroundStyle(.secondary) }
    }.navigationTitle("Cài đặt") }.preferredColorScheme(.dark) }
}
