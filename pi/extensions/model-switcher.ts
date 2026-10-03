import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import {
	Container,
	Input,
	Key,
	SelectList,
	Spacer,
	Text,
	type Focusable,
	type KeybindingsManager,
	type SelectItem,
	type SelectListTheme,
	type TUI,
} from "@earendil-works/pi-tui";

type Model = NonNullable<ExtensionContext["model"]>;
type ThinkingLevel = Parameters<ExtensionAPI["setThinkingLevel"]>[0];
type PickerResult =
	| { type: "model"; model: Model }
	| { type: "thinking"; model: Model; level: ThinkingLevel }
	| { type: "cancel" };

const LEVEL_DESCRIPTIONS: Record<string, string> = {
	off: "No reasoning",
	minimal: "Very brief reasoning",
	low: "Light reasoning",
	medium: "Moderate reasoning",
	high: "Deep reasoning",
	xhigh: "Extra-high reasoning",
	max: "Maximum reasoning",
};

const selectListTheme = (theme: Theme): SelectListTheme => ({
	selectedPrefix: (text) => theme.fg("accent", text),
	selectedText: (text) => theme.fg("accent", text),
	description: (text) => theme.fg("muted", text),
	scrollInfo: (text) => theme.fg("muted", text),
	noMatch: (text) => theme.fg("muted", text),
});

function modelKey(model: Model): string {
	return `${model.provider}/${model.id}`;
}

function getSupportedThinkingLevels(model: Model): ThinkingLevel[] {
	const levels: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];
	if (!model.reasoning) return ["off"];
	return levels.filter((level) => {
		const mapped = model.thinkingLevelMap?.[level];
		if (mapped === null) return false;
		if (level === "xhigh" || level === "max") return mapped !== undefined;
		return true;
	});
}

class ModelSwitcher extends Container implements Focusable {
	private _focused = false;
	private searchInput!: Input;
	private selectList!: SelectList;
	private stage: "models" | "thinking" = "models";
	private searchQuery = "";

	get focused(): boolean {
		return this._focused;
	}

	set focused(value: boolean) {
		this._focused = value;
		this.searchInput.focused = value;
	}

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly keybindings: KeybindingsManager,
		private readonly models: Model[],
		private readonly currentModel: Model | undefined,
		private readonly defaultModel: { provider?: string; id?: string },
		private readonly providerName: (provider: string) => string,
		private readonly preferredThinkingLevel: (model: Model) => ThinkingLevel,
		private readonly onThinkingUnavailable: () => void,
		private readonly done: (result: PickerResult) => void,
		initialSearch = "",
	) {
		super();
		this.searchQuery = initialSearch;
		this.buildModelPicker();
	}

	handleInput(data: string): void {
		if (this.keybindings.matches(data, "tui.select.cancel")) {
			if (this.stage === "thinking") {
				this.buildModelPicker();
			} else {
				this.done({ type: "cancel" });
			}
			return;
		}

		if (this.stage === "models" && this.keybindings.matches(data, "tui.input.tab")) {
			const selected = this.selectList.getSelectedItem();
			const model = selected ? this.models.find((candidate) => modelKey(candidate) === selected.value) : undefined;
			if (!model) return;
			if (!model.reasoning) {
				this.onThinkingUnavailable();
				return;
			}
			this.buildThinkingPicker(model);
			return;
		}

		if (
			this.keybindings.matches(data, "tui.select.up") ||
			this.keybindings.matches(data, "tui.select.down") ||
			this.keybindings.matches(data, "tui.select.confirm")
		) {
			this.selectList.handleInput(data);
			this.tui.requestRender();
			return;
		}

		this.searchInput.handleInput(data);
		if (this.stage === "models") this.searchQuery = this.searchInput.getValue();
		this.selectList.setFilter(this.searchInput.getValue());
		this.tui.requestRender();
	}

	private buildModelPicker(): void {
		this.stage = "models";
		this.clear();
		this.addChild(new Text(this.theme.bold(this.theme.fg("accent", "Switch model")), 0, 0));
		this.addChild(new Spacer(1));
		this.addChild(new Text(this.theme.fg("muted", "Choose a model · Tab to configure its thinking level"), 0, 0));
		this.addChild(new Spacer(1));

		this.searchInput = new Input({ prompt: "> ", placeholder: "Search models by name, provider, or ID" });
		if (this.searchQuery) this.searchInput.setValue(this.searchQuery);
		this.searchInput.focused = this._focused;
		this.addChild(this.searchInput);
		this.addChild(new Spacer(1));

		const items: SelectItem[] = this.models.map((model) => {
			const isCurrent = this.currentModel ? modelKey(model) === modelKey(this.currentModel) : false;
			const isDefault = model.provider === this.defaultModel.provider && model.id === this.defaultModel.id;
			const badges = [isCurrent ? "current" : "", isDefault ? "default" : "", model.reasoning ? "reasoning" : ""]
				.filter(Boolean)
				.join(" · ");
			const context = `${Math.round(model.contextWindow / 1000)}k context`;
			return {
				value: modelKey(model),
				label: `${isCurrent ? "● " : "  "}${model.name || model.id}`,
				description: `${this.providerName(model.provider)} · ${model.id}${badges ? ` · ${badges}` : ""} · ${context}`,
			};
		});

		this.selectList = new SelectList(items, 10, selectListTheme(this.theme), {
			minPrimaryColumnWidth: 16,
			maxPrimaryColumnWidth: 42,
		});
		this.selectList.onSelect = (item) => {
			const model = this.models.find((candidate) => modelKey(candidate) === item.value);
			if (model) this.done({ type: "model", model });
		};
		this.selectList.onCancel = () => this.done({ type: "cancel" });
		this.selectList.setFilter(this.searchQuery);
		this.addChild(this.selectList);
		this.addChild(new Spacer(1));
		this.addChild(new Text(this.theme.fg("dim", "Enter select · Tab thinking · Esc close"), 0, 0));
	}

	private buildThinkingPicker(model: Model): void {
		this.stage = "thinking";
		this.clear();
		this.addChild(new Text(this.theme.bold(this.theme.fg("accent", "Configure thinking")), 0, 0));
		this.addChild(new Spacer(1));
		this.addChild(new Text(this.theme.fg("muted", `${model.name || model.id} · ${this.providerName(model.provider)}`), 0, 0));
		this.addChild(new Spacer(1));

		this.searchInput = new Input({ prompt: "> ", placeholder: "Filter thinking levels" });
		this.searchInput.focused = this._focused;
		this.addChild(this.searchInput);
		this.addChild(new Spacer(1));

		const levels = getSupportedThinkingLevels(model);
		const defaultLevel = this.preferredThinkingLevel(model);
		const items: SelectItem[] = levels.map((level) => ({
			value: level,
			label: `${level === defaultLevel ? "● " : "  "}${level}`,
			description: LEVEL_DESCRIPTIONS[level] ?? "",
		}));
		this.selectList = new SelectList(items, 10, selectListTheme(this.theme), {
			minPrimaryColumnWidth: 16,
			maxPrimaryColumnWidth: 32,
		});
		const levelIndex = items.findIndex((item) => item.value === defaultLevel);
		if (levelIndex >= 0) this.selectList.setSelectedIndex(levelIndex);
		this.selectList.onSelect = (item) => this.done({ type: "thinking", model, level: item.value as ThinkingLevel });
		this.selectList.onCancel = () => this.buildModelPicker();
		this.addChild(this.selectList);
		this.addChild(new Spacer(1));
		this.addChild(new Text(this.theme.fg("dim", "Enter select · Esc back"), 0, 0));
	}
}

export default function modelSwitcherExtension(pi: ExtensionAPI): void {
	const open = async (query: string, ctx: ExtensionContext): Promise<void> => {
		if (ctx.mode !== "tui") {
			ctx.ui.notify("The model switcher requires Pi's interactive terminal UI.", "warning");
			return;
		}

		const scopedModels = ctx.scopedModels.map((scoped) => scoped.model);
		const models = [...(scopedModels.length > 0 ? scopedModels : ctx.modelRegistry.getAvailable())];
		const settings = pi.getSettings();
		const defaultModel = {
			provider: settings.defaultProvider,
			id: settings.defaultModel,
		};
		models.sort((a, b) => {
			const aCurrent = ctx.model && modelKey(a) === modelKey(ctx.model);
			const bCurrent = ctx.model && modelKey(b) === modelKey(ctx.model);
			if (aCurrent !== bCurrent) return aCurrent ? -1 : 1;
			const aDefault = a.provider === defaultModel.provider && a.id === defaultModel.id;
			const bDefault = b.provider === defaultModel.provider && b.id === defaultModel.id;
			if (aDefault !== bDefault) return aDefault ? -1 : 1;
			return a.provider.localeCompare(b.provider) || a.name.localeCompare(b.name);
		});

		const preferredThinkingLevel = (model: Model): ThinkingLevel => {
			const available = getSupportedThinkingLevels(model);
			const scopedLevel = ctx.scopedModels.find((scoped) => modelKey(scoped.model) === modelKey(model))?.thinkingLevel;
			const requested =
				ctx.model && modelKey(ctx.model) === modelKey(model)
					? pi.getThinkingLevel()
					: scopedLevel ?? settings.modelThinkingLevels?.[modelKey(model)] ?? settings.defaultThinkingLevel ?? "medium";
			return available.includes(requested as ThinkingLevel)
				? (requested as ThinkingLevel)
				: available.includes("medium")
					? "medium"
					: (available[0] ?? "off");
		};

		const result = await ctx.ui.custom<PickerResult>(
			(tui, theme, keybindings, done) =>
				new ModelSwitcher(
					tui,
					theme,
					keybindings,
					models,
					ctx.model,
					defaultModel,
					(provider) => ctx.modelRegistry.getProviderDisplayName(provider),
					preferredThinkingLevel,
					() => ctx.ui.notify("This model does not support configurable reasoning.", "info"),
					done,
					query,
				),
			{ overlay: true, overlayOptions: { anchor: "center", width: 76, minWidth: 48, maxHeight: 20 } },
		);

		if (result.type === "cancel") return;
		const selected = await pi.setModel(result.model);
		if (!selected) {
			ctx.ui.notify(`Could not select ${result.model.id}; check provider authentication.`, "error");
			return;
		}
		if (result.type === "thinking") pi.setThinkingLevel(result.level);
		ctx.ui.notify(
			result.type === "thinking"
				? `Model: ${result.model.name || result.model.id} · thinking ${result.level}`
				: `Model: ${result.model.name || result.model.id}`,
			"info",
		);
	};

	pi.registerCommand("model-switcher", {
		description: "Open the searchable model switcher",
		handler: async (query, ctx) => open(query, ctx),
	});

	pi.registerShortcut(Key.ctrl("l"), {
		description: "Open model switcher",
		handler: async (ctx) => open("", ctx),
	});
}
