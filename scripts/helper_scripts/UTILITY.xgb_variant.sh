#!/bin/bash
# Shared configuration for independently named stereo IRF experiments.

xgb_variant_validate()
{
    [[ -z ${XGB_VARIANT:-} ]] && return 0
    if [[ ! $XGB_VARIANT =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
        echo "Error: XGB_VARIANT must contain only letters, digits, underscores and hyphens." >&2
        return 1
    fi
    local path
    for path in "${XGB_SMEARING_CONFIG:-}" "${XGB_MODEL_ROOT:-}"; do
        if [[ -n $path && ! $path =~ ^/[A-Za-z0-9_./-]+$ ]]; then
            echo "Error: variant paths must be absolute and contain only letters, digits, _, -, . and /." >&2
            return 1
        fi
    done
}

# Freeze settings before submission. An existing tag cannot acquire a different configuration.
xgb_variant_prepare()
{
    local base="$1" stage="$2" record config model temp
    xgb_variant_validate || return 1
    [[ -z ${XGB_VARIANT:-} ]] && return 0
    record="$base/XGBVariants/$XGB_VARIANT"
    if [[ $stage == ANAXGBANGRES || $stage == TRAINXGBANGRES ]]; then
        config=${XGB_SMEARING_CONFIG:-}
        [[ -f $config ]] || { echo "Error: set XGB_SMEARING_CONFIG to a YAML file." >&2; return 1; }
        model=${XGB_MODEL_ROOT:-default}
        [[ $model == default || -d $model ]] || { echo "Error: XGB_MODEL_ROOT is not a directory: $model" >&2; return 1; }
        mkdir -p "$(dirname "$record")" || return 1
        temp=$(mktemp -d "${record}.tmp.XXXXXX") || return 1
        cp "$config" "$temp/smearing.yaml" || return 1
        printf '%s\n' "$model" > "$temp/model-root.txt"
        sha256sum "$temp/smearing.yaml" | awk '{print $1}' > "$temp/smearing.sha256"
        if ! mv -T -n "$temp" "$record" || [[ -d $temp ]]; then
            rm -rf "$temp"
        fi
        if ! cmp -s "$config" "$record/smearing.yaml" || [[ $(cat "$record/model-root.txt") != "$model" ]]; then
            echo "Error: variant $XGB_VARIANT already has different settings." >&2; return 1
        fi
    fi
    [[ -f $record/smearing.yaml && -f $record/model-root.txt ]] || {
        echo "Error: variant $XGB_VARIANT has not been prepared by ANAXGBANGRES." >&2; return 1;
    }
    if [[ -n ${XGB_SMEARING_CONFIG:-} ]] && ! cmp -s "$XGB_SMEARING_CONFIG" "$record/smearing.yaml"; then
        echo "Error: smearing configuration does not match variant $XGB_VARIANT." >&2; return 1
    fi
    if [[ $(sha256sum "$record/smearing.yaml" | awk '{print $1}') != "$(cat "$record/smearing.sha256")" ]]; then
        echo "Error: frozen smearing configuration was modified." >&2; return 1
    fi
    XGB_SMEARING_CONFIG="$record/smearing.yaml"
    XGB_MODEL_ROOT=$(cat "$record/model-root.txt")
    [[ $XGB_MODEL_ROOT == default ]] && XGB_MODEL_ROOT=""
    export XGB_VARIANT XGB_SMEARING_CONFIG XGB_MODEL_ROOT
}
