import OpenRouterCreditsCore
import OpenRouterCreditsUI
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                statusCard
                credentialsCard
                optionsCard
                footer
            }
            .padding(20)
            .frame(width: 520)
        }
        .frame(width: 520, height: 730)
        .onAppear { model.onAppear() }
    }

    // MARK: - Intestazione

    private var header: some View {
        HStack(spacing: 12) {
            OpenRouterBadge(size: 46, mark: .white, background: Brand.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.text("OpenRouter Credits"))
                    .font(.system(size: 19, weight: .semibold))
                Text(Strings.text("Credito residuo e spesa, sempre sotto controllo nel widget."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Stato

    private var statusCard: some View {
        card {
            if let snapshot = model.snapshot, let metrics = model.metrics {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metrics.heroValue.map { Format.money($0) } ?? "$--")
                            .font(.system(size: 34, weight: .semibold))
                            .monospacedDigit()
                        Text(metrics.caption)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let detail = metrics.detail {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    if let fraction = metrics.fraction {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(Format.percent(fraction))
                                .font(.system(size: 20, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Brand.purple)
                            Text(Strings.text("residuo"))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if let fraction = metrics.fraction {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Brand.purple.opacity(0.15))
                            Capsule()
                                .fill(Brand.purple)
                                .frame(width: max(4, geometry.size.width * fraction))
                        }
                    }
                    .frame(height: 6)
                }

                Divider()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], alignment: .leading, spacing: 10) {
                    if let total = snapshot.accountTotal {
                        StatTile(title: Strings.text("Crediti acquistati"), value: Format.money(total))
                    }
                    if let usage = snapshot.accountUsage {
                        StatTile(title: Strings.text("Spesa totale"), value: Format.money(usage))
                    }
                    if let limit = snapshot.keyLimit {
                        StatTile(title: Strings.text("Limite chiave"), value: Format.money(limit))
                    }
                    if let remaining = snapshot.keyLimitRemaining, snapshot.accountRemaining == nil {
                        StatTile(title: Strings.text("Residuo chiave"), value: Format.money(remaining))
                    }
                    if let daily = snapshot.usageDaily {
                        StatTile(title: Strings.text("Oggi"), value: Format.money(daily))
                    }
                    if let weekly = snapshot.usageWeekly {
                        StatTile(title: Strings.text("Questa settimana"), value: Format.money(weekly))
                    }
                    if let monthly = snapshot.usageMonthly {
                        StatTile(title: Strings.text("Questo mese"), value: Format.money(monthly))
                    }
                    if let requests = snapshot.freeRequestsRemaining {
                        StatTile(title: Strings.text("Richieste gratuite"), value: "\(requests)")
                    }
                }

                Text(Strings.text("Ultimo aggiornamento: %@", Format.full(snapshot.updatedAt)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.config.hasCredentials
                         ? Strings.text("Nessun dato disponibile")
                         : Strings.text("Benvenuto"))
                        .font(.system(size: 16, weight: .semibold))
                    Text(model.config.hasCredentials
                         ? Strings.text("Controlla la connessione e premi «Aggiorna ora».")
                         : Strings.text("Inserisci qui sotto una chiave API di OpenRouter per iniziare."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if let message = model.statusMessage {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: model.statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(model.statusIsError ? Color.orange : Color.green)
                    Text(message)
                        .font(.system(size: 11.5))
                        .foregroundStyle(model.statusIsError ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Chiavi

    private var credentialsCard: some View {
        card {
            Text(Strings.text("Chiavi OpenRouter"))
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                SecureField(Strings.text("Chiave API (sk-or-v1-...)"), text: $model.apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                Text(Strings.text("Usata per leggere il limite e la spesa della chiave."))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                SecureField(Strings.text("Chiave di gestione (opzionale)"), text: $model.managementKeyInput)
                    .textFieldStyle(.roundedBorder)
                Text(Strings.text("Serve solo per conoscere il saldo del conto (endpoint /credits)."))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                Button(Strings.text("Salva chiavi")) {
                    model.saveCredentials()
                }
                .keyboardShortcut(.defaultAction)

                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(Strings.text("Aggiornamento…"))
                        }
                    } else {
                        Text(Strings.text("Aggiorna ora"))
                    }
                }
                .disabled(model.isRefreshing)

                Spacer()

                Button(Strings.text("Crea una chiave")) {
                    model.openKeysPage()
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: - Opzioni

    private var optionsCard: some View {
        card {
            Text(Strings.text("Preferenze"))
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Text(Strings.text("Schema colori predefinito"))
                Spacer()
                Picker("", selection: Binding(
                    get: { model.config.defaultStyle },
                    set: { model.setDefaultStyle($0) }
                )) {
                    ForEach(WidgetStyleOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            Toggle(Strings.text("Avvia all'accesso"), isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Text(Strings.text("L'app ricontrolla i crediti ogni 4 minuti mentre è aperta; il widget si aggiorna da solo circa ogni 5 minuti."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Piè di pagina

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 14) {
                Button(Strings.text("Pagina dei crediti su OpenRouter")) {
                    model.openCreditsPage()
                }
                .buttonStyle(.link)

                Button(Strings.text("Impostazioni delle chiavi")) {
                    model.openKeysPage()
                }
                .buttonStyle(.link)
            }

            HStack(spacing: 4) {
                Text(Strings.text("Chiavi e dati:"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                Text(model.storagePath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helper

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}