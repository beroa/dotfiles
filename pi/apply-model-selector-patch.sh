#!/usr/bin/env bash
set -euo pipefail

agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
version_file="$agent_dir/install/current-version"

if [[ ! -r "$version_file" ]]; then
    echo "Pi is not installed yet; skipping model-selector customization."
    exit 0
fi

version="$(<"$version_file")"
release="$agent_dir/install/releases/$version/node_modules/@earendil-works/pi-coding-agent"
if [[ ! -d "$release" ]]; then
    echo "Pi release not found: $release" >&2
    exit 1
fi

python3 - "$release" <<'PY'
from pathlib import Path
import sys

release = Path(sys.argv[1])


def apply(path: Path, replacements: list[tuple[str, str]]) -> None:
    text = path.read_text()
    changed = False
    for old, new in replacements:
        if new in text:
            continue
        if old not in text:
            raise RuntimeError(f"Could not find expected Pi code in {path}: {old[:80]!r}")
        text = text.replace(old, new, 1)
        changed = True
    if changed:
        path.write_text(text)
        print(f"Patched {path}")


component = release / "dist/modes/interactive/components/model-selector.js"
apply(
    component,
    [
        (
            "    onSelectAsDefaultCallback;\n    onCancelCallback;",
            "    onSelectAsDefaultCallback;\n    onSelectThinkingCallback;\n    onCancelCallback;",
        ),
        (
            "constructor(tui, currentModel, modelRuntime, scopedModels, onSelect, onCancel, initialSearchInput, onSelectAsDefault, defaultModel) {",
            "constructor(tui, currentModel, modelRuntime, scopedModels, onSelect, onCancel, initialSearchInput, onSelectAsDefault, defaultModel, onSelectThinking) {",
        ),
        (
            "        this.onSelectAsDefaultCallback = onSelectAsDefault;\n        this.onCancelCallback = onCancel;",
            "        this.onSelectAsDefaultCallback = onSelectAsDefault;\n        this.onSelectThinkingCallback = onSelectThinking;\n        this.onCancelCallback = onCancel;",
        ),
        (
            '            this.addChild(new Text(theme.fg("dim", `  ${keyDisplayText("tui.select.confirm")} to select · ${keyDisplayText("app.models.save")} to set as default · ${keyDisplayText("tui.select.cancel")} to cancel`), 0, 0));',
            '            this.addChild(new Text(theme.fg("dim", `  ${keyDisplayText("tui.select.confirm")} to select · ${keyDisplayText("tui.input.tab")} to configure thinking · ${keyDisplayText("app.models.save")} to set as default · ${keyDisplayText("tui.select.cancel")} to cancel`), 0, 0));',
        ),
        (
            '''        if (kb.matches(keyData, "tui.input.tab")) {
            if (this.scopedModelItems.length > 0) {
                const nextScope = this.scope === "all" ? "scoped" : "all";
                this.setScope(nextScope);
                if (this.scopeHintText) {
                    this.scopeHintText.setText(this.getScopeHintText());
                }
            }
            return;
        }''',
            '''        if (kb.matches(keyData, "tui.input.tab")) {
            const selectedModel = this.filteredModels[this.selectedIndex];
            if (selectedModel && this.onSelectThinkingCallback) {
                this.dispose();
                this.onSelectThinkingCallback(selectedModel.model);
            }
            else if (this.scopedModelItems.length > 0) {
                const nextScope = this.scope === "all" ? "scoped" : "all";
                this.setScope(nextScope);
                if (this.scopeHintText) {
                    this.scopeHintText.setText(this.getScopeHintText());
                }
            }
            return;
        }''',
        ),
    ],
)

interactive = release / "dist/modes/interactive/interactive-mode.js"
apply(
    interactive,
    [
        (
            '''            const selectModel = async (model, persist) => {
                try {
                    await this.session.setModel(model, { persist });
                    this.updateAvailableProviderCount();
                    this.footer.invalidate();
                    this.updateEditorBorderColor();
                    done();
                    this.showStatus(persist ? `Default model: ${model.provider}/${model.id}` : `Model: ${model.id}`);
                    void this.maybeWarnAboutAnthropicSubscriptionAuth(model);
                    this.checkDaxnutsEasterEgg(model);
                }
                catch (error) {
                    done();
                    this.showError(error instanceof Error ? error.message : String(error));
                }
            };''',
            '''            const selectModel = async (model, persist) => {
                try {
                    await this.session.setModel(model, { persist });
                    this.updateAvailableProviderCount();
                    this.footer.invalidate();
                    this.updateEditorBorderColor();
                    done();
                    this.showStatus(persist ? `Default model: ${model.provider}/${model.id}` : `Model: ${model.id}`);
                    void this.maybeWarnAboutAnthropicSubscriptionAuth(model);
                    this.checkDaxnutsEasterEgg(model);
                    return true;
                }
                catch (error) {
                    done();
                    this.showError(error instanceof Error ? error.message : String(error));
                    return false;
                }
            };''',
        ),
        (
            '''            const selector = new ModelSelectorComponent(this.ui, this.session.model, this.session.modelRuntime, this.session.scopedModels, (model) => selectModel(model, false), () => {
                done();
                this.ui.requestRender();
            }, initialSearchInput, (model) => selectModel(model, true), defaultProvider && defaultModel ? { provider: defaultProvider, id: defaultModel } : undefined);''',
            '''            const selector = new ModelSelectorComponent(this.ui, this.session.model, this.session.modelRuntime, this.session.scopedModels, (model) => selectModel(model, false), () => {
                done();
                this.ui.requestRender();
            }, initialSearchInput, (model) => selectModel(model, true), defaultProvider && defaultModel ? { provider: defaultProvider, id: defaultModel } : undefined, async (model) => {
                if (await selectModel(model, false)) {
                    this.showThinkingSelector();
                }
            });''',
        ),
    ],
)

chunks = release / "dist/bundle/chunks"
bundle = next(
    (
        path
        for path in chunks.glob("*.js")
        if "ModelSelectorComponent=class" in path.read_text()
        and "showModelSelector(initialSearchInput)" in path.read_text()
    ),
    None,
)
if bundle is None:
    raise RuntimeError("Could not find Pi's bundled interactive code")

apply(
    bundle,
    [
        (
            'constructor(tui,currentModel,modelRuntime,scopedModels,onSelect,onCancel,initialSearchInput,onSelectAsDefault,defaultModel){if(super(),this.tui=tui,this.currentModel=currentModel,this.modelRuntime=modelRuntime,this.scopedModels=scopedModels,this.defaultModel=defaultModel,this.scope=scopedModels.length>0?"scoped":"all",this.onSelectCallback=onSelect,this.onSelectAsDefaultCallback=onSelectAsDefault,this.onCancelCallback=onCancel,',
            'constructor(tui,currentModel,modelRuntime,scopedModels,onSelect,onCancel,initialSearchInput,onSelectAsDefault,defaultModel,onSelectThinking){if(super(),this.tui=tui,this.currentModel=currentModel,this.modelRuntime=modelRuntime,this.scopedModels=scopedModels,this.defaultModel=defaultModel,this.scope=scopedModels.length>0?"scoped":"all",this.onSelectCallback=onSelect,this.onSelectAsDefaultCallback=onSelectAsDefault,this.onSelectThinkingCallback=onSelectThinking,this.onCancelCallback=onCancel,',
        ),
        (
            r'onSelectAsDefaultCallback&&this.addChild(new Text(theme.fg("dim",`  ${keyDisplayText("tui.select.confirm")} to select \xB7 ${keyDisplayText("app.models.save")} to set as default \xB7 ${keyDisplayText("tui.select.cancel")} to cancel`),0,0)),',
            r'onSelectAsDefaultCallback&&this.addChild(new Text(theme.fg("dim",`  ${keyDisplayText("tui.select.confirm")} to select \xB7 ${keyDisplayText("tui.input.tab")} to configure thinking \xB7 ${keyDisplayText("app.models.save")} to set as default \xB7 ${keyDisplayText("tui.select.cancel")} to cancel`),0,0)),',
        ),
        (
            'handleInput(keyData){let kb=getKeybindings();if(kb.matches(keyData,"tui.input.tab")){if(this.scopedModelItems.length>0){let nextScope=this.scope==="all"?"scoped":"all";this.setScope(nextScope),this.scopeHintText&&this.scopeHintText.setText(this.getScopeHintText())}return}if(kb.matches(keyData,"tui.select.up")){',
            'handleInput(keyData){let kb=getKeybindings();if(kb.matches(keyData,"tui.input.tab")){let selectedModel=this.filteredModels[this.selectedIndex];if(selectedModel&&this.onSelectThinkingCallback)this.dispose(),this.onSelectThinkingCallback(selectedModel.model);else if(this.scopedModelItems.length>0){let nextScope=this.scope==="all"?"scoped":"all";this.setScope(nextScope),this.scopeHintText&&this.scopeHintText.setText(this.getScopeHintText())}return}if(kb.matches(keyData,"tui.select.up")){',
        ),
        (
            'showModelSelector(initialSearchInput){this.showSelector(done=>{let selectModel=async(model,persist)=>{try{await this.session.setModel(model,{persist}),this.updateAvailableProviderCount(),this.footer.invalidate(),this.updateEditorBorderColor(),done(),this.showStatus(persist?`Default model: ${model.provider}/${model.id}`:`Model: ${model.id}`),this.maybeWarnAboutAnthropicSubscriptionAuth(model),this.checkDaxnutsEasterEgg(model)}catch(error){done(),this.showError(error instanceof Error?error.message:String(error))}},defaultProvider=this.settingsManager.getDefaultProvider(),defaultModel=this.settingsManager.getDefaultModel(),selector=new ModelSelectorComponent(this.ui,this.session.model,this.session.modelRuntime,this.session.scopedModels,model=>selectModel(model,!1),()=>{done(),this.ui.requestRender()},initialSearchInput,model=>selectModel(model,!0),defaultProvider&&defaultModel?{provider:defaultProvider,id:defaultModel}:void 0);return{component:selector,focus:selector,dispose:()=>selector.dispose()}})}',
            'showModelSelector(initialSearchInput){this.showSelector(done=>{let selectModel=async(model,persist)=>{try{await this.session.setModel(model,{persist}),this.updateAvailableProviderCount(),this.footer.invalidate(),this.updateEditorBorderColor(),done(),this.showStatus(persist?`Default model: ${model.provider}/${model.id}`:`Model: ${model.id}`),this.maybeWarnAboutAnthropicSubscriptionAuth(model),this.checkDaxnutsEasterEgg(model);return!0}catch(error){done(),this.showError(error instanceof Error?error.message:String(error));return!1}},defaultProvider=this.settingsManager.getDefaultProvider(),defaultModel=this.settingsManager.getDefaultModel(),selector=new ModelSelectorComponent(this.ui,this.session.model,this.session.modelRuntime,this.session.scopedModels,model=>selectModel(model,!1),()=>{done(),this.ui.requestRender()},initialSearchInput,model=>selectModel(model,!0),defaultProvider&&defaultModel?{provider:defaultProvider,id:defaultModel}:void 0,async model=>{await selectModel(model,!1)&&this.showThinkingSelector()});return{component:selector,focus:selector,dispose:()=>selector.dispose()}})}',
        ),
    ],
)
PY
