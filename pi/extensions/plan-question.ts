import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const Parameters = Type.Object({
	question: Type.String({ description: "Ask exactly one concise planning question" }),
	options: Type.Array(
		Type.Object({
			label: Type.String({ description: "Choice label" }),
			description: Type.Optional(Type.String({ description: "Brief explanation of this choice" })),
		}),
		{ description: "Prefilled choices; include a recommendation in the label when there is a clear best fit" },
	),
});

export default function planQuestion(pi: ExtensionAPI): void {
	pi.registerTool({
		name: "plan_question",
		label: "Plan question",
		description:
			"Ask one planning question at a time using arrow-key choices. Use this instead of asking the user to type a reply. Include several distinct options and mark a recommended choice when appropriate. The user can press Tab to add notes or choose Other to enter a custom answer. Treat submitted notes as part of the user's answer, carry them forward, and don't repeat a question they have already answered.",
		parameters: Parameters,
		executionMode: "sequential",
		async execute(_id, params, _signal, _update, ctx) {
			if (ctx.mode !== "tui") {
				return { content: [{ type: "text", text: "Plan question requires the interactive TUI." }] };
			}
			if (params.options.length === 0) {
				return { content: [{ type: "text", text: "Provide at least one choice." }] };
			}

			const choices = params.options.filter((option) => !/^other\b/i.test(option.label.trim()));
			if (choices.length === 0) {
				return { content: [{ type: "text", text: "Provide at least one choice besides Other." }] };
			}

			const result = await ctx.ui.custom<{ choice: string; notes: string } | null>((tui, theme, _kb, done) => {
				const options = [...choices, { label: "Other" }];
				let selected = 0;
				let notesMode = false;
				let cached: string[] | undefined;
				const editorTheme: EditorTheme = {
					borderColor: (s) => theme.fg("accent", s),
					selectList: {
						selectedPrefix: (s) => theme.fg("accent", s),
						selectedText: (s) => theme.fg("accent", s),
						description: (s) => theme.fg("muted", s),
						scrollInfo: (s) => theme.fg("dim", s),
						noMatch: (s) => theme.fg("warning", s),
					},
				};
				const editor = new Editor(tui, editorTheme);
				const refresh = () => { cached = undefined; tui.requestRender(); };
				const submit = () => done({ choice: selected === options.length - 1 ? "Other" : options[selected]!.label, notes: editor.getText().trim() });
				editor.onSubmit = submit;

				function handleInput(data: string): void {
					if (notesMode) {
						if (matchesKey(data, Key.escape)) { notesMode = false; refresh(); return; }
						editor.handleInput(data);
						refresh();
						return;
					}
					if (matchesKey(data, Key.tab)) {
						notesMode = true;
						if (selected === options.length - 1 && !editor.getText()) editor.setText("");
						refresh();
						return;
					}
					if (matchesKey(data, Key.up)) { selected = Math.max(0, selected - 1); refresh(); return; }
					if (matchesKey(data, Key.down)) { selected = Math.min(options.length - 1, selected + 1); refresh(); return; }
					if (matchesKey(data, Key.enter)) {
						if (selected === options.length - 1) { notesMode = true; refresh(); }
						else submit();
						return;
					}
					if (matchesKey(data, Key.escape)) done(null);
				}

				function render(width: number): string[] {
					if (cached) return cached;
					const lines: string[] = [];
					const w = Math.max(1, width);
					const add = (text: string, prefix = " ") => {
						const pw = visibleWidth(prefix);
						const wrapped = wrapTextWithAnsi(text, Math.max(1, w - pw));
						for (let i = 0; i < wrapped.length; i++) lines.push(`${i === 0 ? prefix : " ".repeat(pw)}${wrapped[i]}`);
					};
				lines.push(theme.fg("accent", "─".repeat(w)));
				add(theme.fg("text", params.question));
				lines.push("");
				for (let i = 0; i < options.length; i++) {
					const option = options[i]!;
					const isOther = i === options.length - 1;
					const active = i === selected;
					add(theme.fg(active ? "accent" : "text", `${active ? "> " : "  "}${option.label}${isOther && notesMode ? " ✎" : ""}`), "");
					if (option.description) add(theme.fg("muted", option.description), "    ");
				}
				if (notesMode) {
					lines.push("");
					add(theme.fg("muted", selected === options.length - 1 ? "Your answer / notes:" : "Notes:"));
					for (const line of editor.render(Math.max(1, w - 2))) lines.push(` ${line}`);
				}
				lines.push("");
				add(theme.fg("dim", notesMode ? "Enter to submit • Esc to return to choices" : "↑↓ choose • Enter submit • Tab add notes • Esc cancel"));
				lines.push(theme.fg("accent", "─".repeat(w)));
				cached = lines;
				return lines;
				}
				return { render, invalidate: () => { cached = undefined; }, handleInput };
			});

			if (!result) return { content: [{ type: "text", text: "User cancelled the planning question." }] };
			const answer = result.choice === "Other"
				? result.notes
					? `User's custom answer: ${result.notes}`
					: "User selected Other but did not provide a custom answer."
				: `User selected: ${result.choice}${result.notes ? `\nAdditional information from the user: ${result.notes}` : ""}`;
			return {
				content: [{ type: "text", text: answer }],
				details: result,
			};
		},
		renderCall(args, theme) {
			return new Text(theme.fg("toolTitle", theme.bold("Plan question ")) + theme.fg("muted", String(args.question ?? "")), 0, 0);
		},
	});
}
