import ShixinStressPowerCore
import SwiftUI

struct DataOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DataOverviewHeader()
                SystemDataOverviewSection()
            }
            .padding(22)
        }
    }
}

private struct DataOverviewHeader: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                DataOverviewShareExportButton()
            }
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                DataOverviewShareExportButton()
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.t("数据概览"))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text(L10n.t("功耗、温度、风扇、频率与热状态总览"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

struct RealtimeCurvesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let samples = appState.liveSession?.samples ?? appState.liveSamples
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RealtimeCurvesHeader(samples: samples)
                RealtimeCurvesSection(samples: samples)
            }
            .padding(22)
        }
    }
}

private struct RealtimeCurvesHeader: View {
    var samples: [TelemetrySample]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                TelemetryCurveExportButton(samples: samples)
            }
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                TelemetryCurveExportButton(samples: samples)
            }
        }
        .labGlassCard(padding: 16, cornerRadius: 18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.t("实时曲线"))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text(L10n.t("功耗、温度、频率、负载、模块温度与风扇转速曲线"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct RealtimeCurvesSection: View {
    var samples: [TelemetrySample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "实时曲线", systemImage: "chart.xyaxis.line", help: "这里集中展示最近采样的功耗、温度、频率、负载、模块温度和风扇转速曲线。曲线用于观察趋势，单点数值请结合实时监测卡片一起看。")
            RealtimeCurvesStack(samples: samples)
                .equatable()
        }
    }
}
