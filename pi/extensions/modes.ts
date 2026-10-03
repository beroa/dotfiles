import type {
	ExtensionAPI,
	ExtensionContext,
	ReadonlyFooterDataProvider,
	Theme,
} from "@earendil-works/pi-coding-agent";
import { Key, truncateToWidth, type Component, type TUI } from "@earendil-works/pi-tui";

const MODE_ENTRY = "assistant-mode";
const LEGACY_MODE_ENTRY = "ask-mode";
const MODES = ["normal", "ask", "plan"] as const;
type AssistantMode = (typeof MODES)[number];

function isAssistantMode(value: unknown): value is AssistantMode {
	return typeof value === "string" && MODES.includes(value as AssistantMode);
}

function shortPath(cwd: string): string {
	const home = process.env.HOME;
	if (!home) return cwd;
	if (cwd === home) return "~";
	return cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
}

function formatTokens(tokens: number): string {
	if (tokens < 1000) return String(tokens);
	if (tokens < 10000) return `${(tokens / 1000).toFixed(1)}k`;
	return `${Math.round(tokens / 1000)}k`;
}

interface UsageTotals {
	cost: number;
}

function collectUsage(ctx: ExtensionContext): UsageTotals {
	const totals: UsageTotals = { cost: 0 };
	const add = (usage?: { cost: { total: number } }) => {
		if (usage) totals.cost += usage.cost.total;
	};

	for (const entry of ctx.sessionManager.getEntries()) {
		if (entry.type === "usage") add(entry.usage);
		else if (entry.type === "message") {
			if (entry.message.role === "assistant" || entry.message.role === "toolResult") add(entry.message.usage);
		} else if (entry.type === "branch_summary" || entry.type === "compaction") add(entry.usage);
	}
	return totals;
}

class ModeFooter implements Component {
	private readonly unsubscribeBranch: () => void;

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly footerData: ReadonlyFooterDataProvider,
		private readonly getContext: () => ExtensionContext | undefined,
		private readonly getMode: () => AssistantMode,
		private readonly getUsage: () => UsageTotals,
	) {
		this.unsubscribeBranch = footerData.onBranchChange(() => this.refresh());
	}

	render(width: number): string[] {
		const ctx = this.getContext();
		const cwd = shortPath(ctx?.cwd ?? process.cwd());
		const branch = this.footerData.getGitBranch();
		const sessionName = ctx?.sessionManager.getSessionName();
		const firstLine = [cwd, branch ? `(${branch})` : "", sessionName ? `· ${sessionName}` : ""]
			.filter(Boolean)
			.join(" ");

		const mode = this.getMode();
		const modeColor = mode === "normal" ? "success" : mode === "ask" ? "accent" : "warning";
		const details = [`MODE ${mode.toUpperCase()}`];
		if (ctx?.model) {
			details.push(ctx.model.id);
			if (ctx.model.reasoning) details.push(ctx.thinkingLevel ?? "off");
		}
		const totals = this.getUsage();
		if (totals.cost > 0) details.push(`$${totals.cost.toFixed(3)}`);
		const usage = ctx?.getContextUsage();
		if (usage) {
			const used = usage.tokens === null ? "?" : formatTokens(usage.tokens);
			const percent = usage.percent === null ? "?" : `${usage.percent.toFixed(1)}%`;
			details.push(`${used}/${formatTokens(usage.contextWindow)} (${percent})`);
		}
		for (const [key, text] of this.footerData.getExtensionStatuses()) {
			if (key !== "mode" && key !== "ask-mode" && text.trim()) details.push(text.replace(/\s+/g, " ").trim());
		}

		const first = truncateToWidth(this.theme.fg("dim", firstLine), width, this.theme.fg("dim", "…"));
		const modeText = this.theme.fg(modeColor, details[0]!);
		const remaining = details.slice(1).join(" · ");
		const secondLine = remaining ? `${modeText} · ${this.theme.fg("muted", remaining)}` : modeText;
		return [first, truncateToWidth(secondLine, width, this.theme.fg("dim", "…"))];
	}

	invalidate(): void {}

	dispose(): void {
		this.unsubscribeBranch();
	}

	refresh(): void {
		this.tui.requestRender();
	}
}

export default function modesExtension(pi: ExtensionAPI): void {
	let mode: AssistantMode = "normal";
	let normalTools: string[] | undefined;
	let currentContext: ExtensionContext | undefined;
	let footer: ModeFooter | undefined;
	let usageTotals: UsageTotals = { cost: 0 };

	function applyMode(ctx: ExtensionContext, persist = true): void {
		if (mode === "normal") {
			if (normalTools !== undefined) pi.setActiveTools(normalTools);
			normalTools = undefined;
		} else {
			normalTools ??= pi.getActiveTools();
			if (mode === "ask") pi.setActiveTools([]);
			else pi.setActiveTools([...normalTools.filter((tool) => tool !== "edit" && tool !== "write"), "plan_question"]);
		}

		ctx.ui.setStatus("ask-mode", undefined);
		ctx.ui.setStatus("mode", undefined);
		footer?.refresh();
		if (persist) pi.appendEntry(MODE_ENTRY, { mode, normalTools });
	}

	function installFooter(ctx: ExtensionContext): void {
		currentContext = ctx;
		if (ctx.mode !== "tui") return;
		ctx.ui.setFooter((tui, theme, footerData) => {
			footer = new ModeFooter(tui, theme, footerData, () => currentContext, () => mode, () => usageTotals);
			return footer;
		});
	}

	function setMode(next: AssistantMode, ctx: ExtensionContext): void {
		mode = next;
		applyMode(ctx);
		const label = mode === "normal" ? "Normal" : mode === "ask" ? "Ask" : "Plan";
		ctx.ui.notify(`${label} mode: ${mode === "ask" ? "tools disabled" : mode === "plan" ? "read-only tools enabled" : "tools enabled"}`, "info");
	}

	function cycleMode(ctx: ExtensionContext): void {
		const currentIndex = MODES.indexOf(mode);
		setMode(MODES[(currentIndex + 1) % MODES.length]!, ctx);
	}

	pi.registerCommand("mode", {
		description: "Choose normal, ask, or plan mode",
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase();
			if (requested) {
				if (!isAssistantMode(requested)) {
					ctx.ui.notify("Usage: /mode [normal|ask|plan]", "warning");
					return;
				}
				setMode(requested, ctx);
				return;
			}

			if (!ctx.hasUI) {
				ctx.ui.notify("Usage: /mode [normal|ask|plan]", "info");
				return;
			}
			const selected = await ctx.ui.select("Assistant mode", [...MODES]);
			if (isAssistantMode(selected)) setMode(selected, ctx);
		},
	});

	pi.registerCommand("ask-mode", {
		description: "Toggle between ask and normal mode",
		handler: async (_args, ctx) => setMode(mode === "ask" ? "normal" : "ask", ctx),
	});

	pi.registerShortcut(Key.shift("tab"), {
		description: "Cycle normal, ask, and plan modes",
		handler: cycleMode,
	});

	pi.on("before_agent_start", async () => {
		if (mode === "ask") {
			return {
				message: {
					customType: "assistant-mode-ask",
					content:
						"Ask mode is active. Answer the user's question directly without using tools. If the user requests work that requires tools, suggest `/mode normal` or Shift+Tab to switch modes.",
					display: false,
				},
			};
		}
		if (mode === "plan") {
			return {
				message: {
					customType: "assistant-mode-plan",
					content: "Plan mode is active. You may use read-only tools to investigate, but never edit files or make changes. Clarify the request by asking exactly one question at a time with the plan_question tool. Provide a concise question and distinct prefilled choices; mark a recommendation when one is clearly best. Wait for the user's answer before asking the next question. The user can select with arrow keys, press Enter to submit, press Tab to add notes to a choice, or choose Other to enter a custom answer. Once you have enough information, present the plan and stop; do not ask for approval and do not begin implementation.",
					display: false,
				},
			};
		}
	});

	pi.on("agent_end", async (_event, ctx) => {
		usageTotals = collectUsage(ctx);
		footer?.refresh();
	});

	pi.on("session_start", async (_event, ctx) => {
		const state = ctx.sessionManager
			.getEntries()
			.filter(
				(entry) =>
					entry.type === "custom" &&
					(entry.customType === MODE_ENTRY || entry.customType === LEGACY_MODE_ENTRY),
			)
			.at(-1) as { data?: { mode?: unknown; enabled?: boolean; normalTools?: string[] } } | undefined;
		const savedMode = state?.data?.mode === "interview" ? "plan" : state?.data?.mode;
		mode = isAssistantMode(savedMode) ? savedMode : state?.data?.enabled ? "ask" : "normal";
		normalTools = state?.data?.normalTools;
		usageTotals = collectUsage(ctx);
		installFooter(ctx);
		applyMode(ctx, false);
	});
}
