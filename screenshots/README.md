# Screenshots

The main README expects `speedtest-tab.png` here: the dashboard open on the **Speed test** tab, ideally right after a run.

```sh
grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" -g "$(slurp)" speedtest-tab.png
```

(`slurp` lets you drag a box around the dashboard.)
