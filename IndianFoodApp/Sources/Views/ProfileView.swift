import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = store.profile {
                    profileSummary(profile)
                } else {
                    setupPrompt
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showForm) {
                ProfileFormView(existing: store.profile) { saved in
                    store.save(saved)
                }
            }
        }
    }

    // MARK: - Setup prompt (no profile yet)

    private var setupPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.orange.opacity(0.8))

            VStack(spacing: 8) {
                Text("Personalise Your Goals")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Enter your details to calculate a\ncalorie goal tailored to you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showForm = true
            } label: {
                Label("Set Up Profile", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Summary card (profile set)

    private func profileSummary(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Calorie goal card
                summaryCard(profile: profile)

                // Stats grid
                statsGrid(profile: profile)

                // Edit button
                Button {
                    showForm = true
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(14)
                }
                .padding(.horizontal)

                // Clear button
                Button(role: .destructive) {
                    store.clear()
                } label: {
                    Text("Clear Profile")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func summaryCard(profile: UserProfile) -> some View {
        let bmr  = TDEECalculator.calculateBMR(profile: profile)
        let tdee = TDEECalculator.calculateTDEE(profile: profile)
        let goal = store.dailyCalorieGoal

        return VStack(spacing: 16) {
            Text("\(goal)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
            Text("kcal daily goal")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 0) {
                statItem(label: "BMR",  value: "\(Int(bmr)) kcal")
                Divider().frame(height: 36)
                statItem(label: "TDEE", value: "\(Int(tdee)) kcal")
                Divider().frame(height: 36)
                statItem(label: "Goal", value: profile.goalType.rawValue)
            }

            // Macro overview row
            Divider()

            HStack(spacing: 0) {
                statItem(label: "Protein",
                         value: "\(Int(store.dailyProteinGoal))g"
                             + (profile.macroOverride != nil ? " ✎" : ""))
                Divider().frame(height: 36)
                statItem(label: "Carbs",
                         value: "\(Int(store.dailyCarbsGoal))g"
                             + (profile.macroOverride != nil ? " ✎" : ""))
                Divider().frame(height: 36)
                statItem(label: "Fat",
                         value: "\(Int(store.dailyFatGoal))g"
                             + (profile.macroOverride != nil ? " ✎" : ""))
            }

            if profile.macroOverride != nil {
                Label("Custom macros active", systemImage: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func statsGrid(profile: UserProfile) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            infoTile(icon: "person.fill",       label: "Sex",        value: profile.biologicalSex.rawValue)
            infoTile(icon: "calendar",          label: "Age",        value: "\(profile.age) yrs")
            infoTile(icon: "ruler",             label: "Height",     value: heightDisplay(profile))
            infoTile(icon: "scalemass.fill",    label: "Weight",     value: weightDisplay(profile))
            infoTile(icon: "figure.walk",       label: "Activity",   value: profile.activityLevel.rawValue)
            infoTile(icon: "target",            label: "Adjustment", value: adjustmentDisplay(profile))
            infoTile(icon: "leaf.fill",         label: "Diet",       value: dietDisplay(profile))
        }
    }

    private func dietDisplay(_ p: UserProfile) -> String {
        if p.dietaryPreferences.isEmpty { return "None" }
        return p.dietaryPreferences.map(\.displayLabel).sorted().joined(separator: ", ")
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoTile(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundColor(.secondary)
                Text(value).font(.subheadline).fontWeight(.medium)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private func heightDisplay(_ p: UserProfile) -> String {
        if p.unitSystem == .imperial {
            let totalInches = p.heightCM / 2.54
            let ft = Int(totalInches) / 12
            let inch = Int(totalInches) % 12
            return "\(ft)′ \(inch)″"
        }
        return "\(Int(p.heightCM)) cm"
    }

    private func weightDisplay(_ p: UserProfile) -> String {
        if p.unitSystem == .imperial {
            return String(format: "%.1f lb", p.weightKG * 2.20462)
        }
        return String(format: "%.1f kg", p.weightKG)
    }

    private func adjustmentDisplay(_ p: UserProfile) -> String {
        let adj = p.calorieAdjustment
        if adj == 0 { return "None" }
        return adj > 0 ? "+\(adj) kcal" : "\(adj) kcal"
    }
}

// MARK: - Profile Form

struct ProfileFormView: View {
    let existing:  UserProfile?
    let onSave:    (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state — personal details
    @State private var unitSystem:        UnitSystem    = .metric
    @State private var biologicalSex:     BiologicalSex = .male
    @State private var age:               Int           = 25
    @State private var goalType:          GoalType      = .maintain
    @State private var activityLevel:     ActivityLevel = .moderate
    @State private var calorieAdjustment: Int           = 0

    // Height/weight (canonical metric; imperial derived on-the-fly)
    @State private var heightCM:  Double = 170
    @State private var weightKG:  Double = 70
    @State private var heightFt:  Int    = 5
    @State private var heightIn:  Int    = 7
    @State private var weightLbs: Double = 154

    // Macro override state
    @State private var customMacrosEnabled: Bool   = false
    @State private var customProtein:       Double = 0
    @State private var customCarbs:         Double = 0
    @State private var customFat:           Double = 0

    // Dietary preferences
    @State private var dietaryPreferences: Set<DietaryFilter> = []

    // Cut/Bulk presets
    private let cutOptions:  [Int] = [-250, -500, -750]
    private let bulkOptions: [Int] = [250, 500]

    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                personalSection
                activitySection
                goalSection
                dietarySection
                macroOverrideSection
            }
            .navigationTitle(existing == nil ? "Set Up Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.orange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAndDismiss() }
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Sections

    private var unitsSection: some View {
        Section("Display Units") {
            Picker("Unit System", selection: $unitSystem) {
                ForEach(UnitSystem.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: unitSystem) { _, _ in syncImperial() }
        }
    }

    private var personalSection: some View {
        Section("Personal Details") {
            Picker("Biological Sex", selection: $biologicalSex) {
                ForEach(BiologicalSex.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Stepper("Age: \(age) yrs", value: $age, in: 10...100)

            if unitSystem == .metric {
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("cm", value: $heightCM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("cm").foregroundColor(.secondary)
                }

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("kg", value: $weightKG, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg").foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("Height")
                    Spacer()
                    Stepper("\(heightFt)′ \(heightIn)″",
                            onIncrement: { incrementHeight() },
                            onDecrement: { decrementHeight() })
                }

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("lb", value: $weightLbs, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("lb").foregroundColor(.secondary)
                }
            }
        }
    }

    private var activitySection: some View {
        Section("Activity Level") {
            Picker("Activity", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    VStack(alignment: .leading) {
                        Text(level.rawValue)
                        Text(level.shortLabel).font(.caption).foregroundColor(.secondary)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.inline)
        }
    }

    private var goalSection: some View {
        Section("Goal") {
            Picker("Goal Type", selection: $goalType) {
                ForEach(GoalType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: goalType) { _, newVal in
                switch newVal {
                case .maintain: calorieAdjustment = 0
                case .cut:      calorieAdjustment = -500
                case .bulk:     calorieAdjustment = 250
                }
                refreshCalculatedMacros()
            }

            if goalType == .cut {
                Picker("Deficit", selection: $calorieAdjustment) {
                    ForEach(cutOptions, id: \.self) { Text("\($0) kcal/day").tag($0) }
                }
                .onChange(of: calorieAdjustment) { _, _ in refreshCalculatedMacros() }
            }

            if goalType == .bulk {
                Picker("Surplus", selection: $calorieAdjustment) {
                    ForEach(bulkOptions, id: \.self) { Text("+\($0) kcal/day").tag($0) }
                }
                .onChange(of: calorieAdjustment) { _, _ in refreshCalculatedMacros() }
            }

            // Live calorie preview
            let preview = previewGoal
            HStack {
                Text("Estimated daily goal")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(preview) kcal")
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Dietary preferences section

    private var dietarySection: some View {
        Section {
            ForEach(DietaryFilter.allCases) { filter in
                Toggle(filter.displayLabel, isOn: Binding(
                    get: { dietaryPreferences.contains(filter) },
                    set: { isOn in
                        if isOn { dietaryPreferences.insert(filter) }
                        else    { dietaryPreferences.remove(filter) }
                    }
                ))
                .tint(.orange)
            }
        } header: {
            Text("Dietary Preferences")
        } footer: {
            Text("Used to pre-filter search results and warn when a scanned dish conflicts. You can still log anything.")
        }
    }

    // MARK: - Macro override section

    private var macroOverrideSection: some View {
        Section {
            Toggle("Customize Macros", isOn: $customMacrosEnabled)
                .tint(.orange)
                .onChange(of: customMacrosEnabled) { _, enabled in
                    if enabled {
                        refreshCalculatedMacros()
                    }
                    // When disabled: override will be set to nil on save
                }

            if customMacrosEnabled {
                macroField(label: "Protein", value: $customProtein, unit: "g")
                macroField(label: "Carbs",   value: $customCarbs,   unit: "g")
                macroField(label: "Fat",     value: $customFat,     unit: "g")

                // Live kcal readout — informational only, not forced to match goal
                let totalKcal = customProtein * 4 + customCarbs * 4 + customFat * 9
                let goalKcal  = Double(previewGoal)
                let delta     = totalKcal - goalKcal

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Total from macros")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(totalKcal)) kcal")
                            .fontWeight(.semibold)
                            .foregroundColor(abs(delta) < 50 ? .green : .orange)
                    }
                    Text(delta == 0 ? "Matches your goal exactly"
                         : String(format: "%+.0f kcal vs. goal", delta))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Macro Targets")
        } footer: {
            if customMacrosEnabled {
                Text("Custom values override the calculated protein/carbs/fat targets. The calorie goal is unchanged.")
            } else {
                Text("Calculated using protein-per-kg body weight (Cut 2.2 g/kg · Maintain 1.6 g/kg · Bulk 1.8 g/kg).")
            }
        }
    }

    private func macroField(label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private var previewGoal: Int {
        TDEECalculator.calculateDailyGoal(profile: buildProfile())
    }

    /// Refresh custom-macro fields with freshly calculated values.
    private func refreshCalculatedMacros() {
        let p = buildProfile()
        customProtein = TDEECalculator.calculateProteinGoal(profile: p)
        customCarbs   = TDEECalculator.calculateCarbGoal(profile: p)
        customFat     = TDEECalculator.calculateFatGoal(profile: p)
    }

    private func buildProfile() -> UserProfile {
        let cm: Double
        let kg: Double
        if unitSystem == .imperial {
            cm = Double(heightFt * 12 + heightIn) * 2.54
            kg = weightLbs / 2.20462
        } else {
            cm = heightCM
            kg = weightKG
        }
        let override: MacroOverride? = customMacrosEnabled
            ? MacroOverride(proteinG: customProtein, carbsG: customCarbs, fatG: customFat)
            : nil

        return UserProfile(
            age:                age,
            biologicalSex:      biologicalSex,
            heightCM:           cm,
            weightKG:           kg,
            activityLevel:      activityLevel,
            goalType:           goalType,
            calorieAdjustment:  goalType == .maintain ? 0 : calorieAdjustment,
            unitSystem:         unitSystem,
            macroOverride:      override,
            dietaryPreferences: dietaryPreferences
        )
    }

    private func saveAndDismiss() {
        onSave(buildProfile())
        dismiss()
    }

    private func populateIfEditing() {
        guard let p = existing else { return }
        unitSystem        = p.unitSystem
        biologicalSex     = p.biologicalSex
        age               = p.age
        goalType          = p.goalType
        calorieAdjustment = p.calorieAdjustment
        activityLevel     = p.activityLevel
        heightCM          = p.heightCM
        weightKG          = p.weightKG
        dietaryPreferences = p.dietaryPreferences
        syncImperial()

        if let ov = p.macroOverride {
            customMacrosEnabled = true
            customProtein       = ov.proteinG
            customCarbs         = ov.carbsG
            customFat           = ov.fatG
        } else {
            customMacrosEnabled = false
            refreshCalculatedMacros()
        }
    }

    private func syncImperial() {
        let totalIn = heightCM / 2.54
        heightFt  = Int(totalIn) / 12
        heightIn  = Int(totalIn) % 12
        weightLbs = weightKG * 2.20462
    }

    private func incrementHeight() {
        heightIn += 1
        if heightIn >= 12 { heightIn = 0; heightFt += 1 }
        heightCM = Double(heightFt * 12 + heightIn) * 2.54
    }

    private func decrementHeight() {
        if heightIn > 0 {
            heightIn -= 1
        } else if heightFt > 0 {
            heightFt -= 1; heightIn = 11
        }
        heightCM = Double(heightFt * 12 + heightIn) * 2.54
    }
}
