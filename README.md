# AI Coding Agents Comparison 2025

For testing, the task will be to write a fairly simple and small application.

It will be a flutter desktop application that shows an EUR/USD candlestick chart.

A standard empty application will be created to provide a single starting point: `flutter create testai_chart_quotes`.

The First prompt will be most difficult and will ask the agent to implement the main part of the application. Subsequent prompts are logically smaller and will add features. Here are the prompts: https://github.com/liiws/testai-chart-quotes/blob/master/prompts.txt

It's important to note that the Alpha Vantage API was chosen on AI's recommendation, but later it turned out that its demo access was very limited and provided very little functionality. Consequently, the validation of prompt 5 was limited to a compilation check only.

**Software used:**
- **Cursor** 2.1.39. Models listed: Opus 4.5, Sonnet 4.5, GPT 5.1 Codex, GPT 5.1, Gemini 3 Pro, GPT 5.1 Codex Mini, Grok Code, GPT 4.1
- **VS Code** 1.106.3
- **GitHub Copilot** 1.388.0, GitHub Copilot Chat 0.33.3
- **Roo Code** 3.34.8
- **Continue** 1.2.11
- **Kilo Code** 4.125.1

Below are the results. Some iterations are not listed or counted due to issues with the Alpha Vantage demo API and manual URL fixes required to make it work.

Agent|Prompt #|Iteration #|Time (mm:ss)|Cost ($)|Comment
-|-|-|-|-|-
Cursor, auto|1|${\color{green}{1}}$|3:34
&nbsp;|2|${\color{red}{1}}$|3:44||Runtime error
&nbsp;||${\color{green}{2}}$|0:35|
&nbsp;|3|${\color{green}{1}}$|0:39|
&nbsp;|4|${\color{green}{1}}$|0:38|
&nbsp;|5|${\color{green}{1}}$|1:49||Other iterations are not counted because it was fault of the demo API
&nbsp;|6|${\color{green}{1}}$|2:31|
Cursor, GPT 4.1|1|${\color{red}{1}}$|0:51||Compilation error, Manual editing
&nbsp;||${\color{red}{2}}$|0:08||Runtime error
&nbsp;||${\color{red}{3}}$|0:12||Runtime error, Manual URL suggest
&nbsp;||${\color{green}{4}}$|0:10
&nbsp;|2|${\color{green}{1}}$|0:17|
&nbsp;|3|${\color{green}{1}}$|0:10|
&nbsp;|4|${\color{green}{1}}$|0:10|
&nbsp;|5|${\color{green}{1}}$|0:35||Other iterations are not counted because it was fault of the demo API
&nbsp;|6|${\color{green}{1}}$|0:24|
Cursor, GPT 4.1, Try 2|1|${\color{red}{1}}$|0:28||Compilation error
&nbsp;||${\color{red}{2}}$|0:19||Compilation error
&nbsp;||${\color{green}{3}}$|0:15||Chart looks wrong. Stopped to try
Copilot, GPT 4.1|1|${\color{red}{1}}$|0:36||Compilation error, Manual editing
&nbsp;||${\color{red}{2}}$|0:11||Runtime error
&nbsp;||${\color{red}{3}}$|0:07||Runtime error
&nbsp;||${\color{red}{4}}$|0:08||Runtime error
&nbsp;||${\color{red}{5}}$|0:06||Runtime error
&nbsp;||${\color{red}{6}}$|0:10||Runtime error
&nbsp;||${\color{red}{7}}$|0:08||Runtime error
&nbsp;||${\color{red}{8}}$|0:08||Runtime error. Stopped to try (same error)
Copilot, GPT 4.1, after Cursor GPT 4.1 prompt 1 fixed|2|${\color{green}{1}}$|0:32
&nbsp;|3|${\color{green}{1}}$|0:11|
&nbsp;|4|${\color{green}{1}}$|0:08|
&nbsp;|5|${\color{red}{1}}$|0:27|
&nbsp;||${\color{green}{2}}$|0:06||URL format fixed manually
&nbsp;|6|${\color{red}{1}}$|0:21|Compilation error
&nbsp;||${\color{red}{2}}$|0:10||Compilation error
&nbsp;||${\color{red}{3}}$|0:12||Compilation error
&nbsp;||${\color{green}{4}}$|0:08
Copilot, Openrouter GPT 4.1|1|${\color{red}{1}}$|1:36|0.16|Compilation error
&nbsp;||${\color{red}{2}}$|0:18|0.05|Chart looks wrong
&nbsp;||${\color{red}{3}}$|0:25|0.04|Compilation error
&nbsp;||${\color{red}{4}}$|0:23|0.05|Compilation error
&nbsp;||${\color{red}{5}}$|0:16|0.08|Chart looks wrong
&nbsp;||${\color{red}{6}}$|0:14|0.04|Chart looks wrong
&nbsp;||${\color{red}{7}}$|0:16|0.04|Chart looks wrong. Stopped to try (same wrong result)
Roo Code, Openrouter GPT 4.1|1|${\color{red}{1}}$|1:49|0.40|Runtime error
&nbsp;||${\color{red}{2}}$|0:41|0.11|Runtime error
&nbsp;||${\color{red}{3}}$|0:24|0.08|Runtime error. Stopped to try (same error)
Continue, Openrouter GPT 4.1|1|${\color{red}{1}}$|0:11|0.01|Compilation error, many. Stopped to try (it could not edit files himself, everything manually)
Copilot, Openrouter Grok 4.1 Fast|1|${\color{green}{1}}$|1:39
&nbsp;|2|${\color{green}{1}}$|1:37
&nbsp;|3|${\color{green}{1}}$|0:52
&nbsp;|4|${\color{red}{1}}$|2:04||Compilation error
&nbsp;||${\color{red}{2}}$|0:55||Compilation error
&nbsp;||${\color{green}{3}}$|0:48
Kilo Code, Openrouter GPT 4.1|1|${\color{red}{1}}$|1:09|0.22|Runtime error
&nbsp;||${\color{red}{2}}$|0:15|0.08|Runtime error
&nbsp;||${\color{red}{3}}$|0:14|0.05|Chart is empty. Manual edition for debug info
&nbsp;||${\color{red}{4}}$|0:36|0.08|Runtime error
&nbsp;||${\color{green}{5}}$|1:00|0.54
&nbsp;|2|${\color{green}{1}}$|0:28|0.19
&nbsp;|3|${\color{green}{1}}$|0:17|0.16
&nbsp;|4|${\color{green}{1}}$|0:20|0.06
&nbsp;|5|${\color{green}{1}}$|0:35|0.24
&nbsp;|6|${\color{green}{1}}$|1:32|0.33|No checkbox to remove SMA
&nbsp;||${\color{green}{2}}$|0:20|0.21
