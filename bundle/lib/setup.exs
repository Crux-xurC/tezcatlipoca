# lib/setup.exs -- `tezcatlipoca setup`: write Poca's box rows for this bundle.
# Run by bin/tezcatlipoca through the bundled relay's `eval` (Elixir's JSON,
# nothing else needed). argv: <bundle dir> [--fs-root <dir>] [--emacs <cmd> | --no-emacs]
#
# Rows (Poca's README, box.json): "tezcatl" (the pages and the relay, with
# Poca's secret), "xipe_totec" (its server on :4200) and "emacs" (an Emacs
# daemon with this bundle's emacs-vent). Only rows of these names are
# replaced; the person's other rows stay. The file before is kept as
# box.json.bak-<time>.

[bundle | args] = System.argv()

{opts, rest, bad} =
  OptionParser.parse(args, strict: [fs_root: :string, emacs: :string, no_emacs: :boolean])

if rest != [] or bad != [] do
  IO.puts(:stderr, "usage: tezcatlipoca setup [--fs-root <dir>] [--emacs <command> | --no-emacs]")
  System.halt(2)
end

home = System.user_home!()
fs_root = Path.expand(opts[:fs_root] || home)

unless File.dir?(fs_root) do
  IO.puts(:stderr, "tezcatlipoca setup: --fs-root #{fs_root} is not a directory")
  System.halt(1)
end

config_dir =
  case System.get_env("XDG_CONFIG_HOME") do
    d when is_binary(d) and d != "" -> Path.join(d, "poca")
    _ -> Path.join(home, ".config/poca")
  end

box_file = Path.join(config_dir, "box.json")

emacs =
  cond do
    opts[:no_emacs] -> nil
    opts[:emacs] -> System.find_executable(opts[:emacs]) || opts[:emacs]
    true -> System.find_executable("emacs")
  end

if !opts[:no_emacs] and emacs == nil do
  IO.puts(:stderr, "tezcatlipoca setup: no emacs on PATH -- name one with --emacs <command>, or --no-emacs")
  System.halt(1)
end

# emacs-vent, loaded after the person's own init; it needs the websocket package
vent = Path.join(bundle, "emacs-vent")

load_vent =
  "(progn (add-to-list 'load-path #{inspect(vent)}) (require 'emacs-vent-out) " <>
    "(require 'emacs-vent-in) (emacs-vent-mode 1))"

rows =
  [
    %{
      "name" => "tezcatl",
      "ports" => [4001, 4100],
      "auth" => true,
      "run" => [Path.join(bundle, "tezcatl/bin/t")],
      "cwd" => Path.join(bundle, "tezcatl"),
      "env" => %{"TEZCATL_FS_ROOT" => fs_root}
    },
    %{
      "name" => "xipe_totec",
      "ports" => [4200],
      "run" => [
        Path.join(bundle, "xipe_totec/bin/xipe"),
        "start",
        "--port",
        "4200",
        "--lsp",
        "ws://127.0.0.1:4100/lsp",
        "--fs-root",
        fs_root
      ],
      "cwd" => fs_root
    }
  ] ++
    if emacs,
      do: [
        %{
          "name" => "emacs",
          "ports" => [4000],
          "run" => [emacs, "--fg-daemon=tezcatlipoca", "--eval", load_vent],
          "cwd" => fs_root
        }
      ],
      else: []

ours = ["tezcatl", "xipe_totec", "emacs"]

{box, kept} =
  case File.read(box_file) do
    {:ok, text} ->
      case JSON.decode(text) do
        {:ok, %{"programs" => programs} = box} when is_list(programs) ->
          {box, Enum.reject(programs, &(&1["name"] in ours))}

        _ ->
          IO.puts(:stderr, "tezcatlipoca setup: #{box_file} is not a box.json ({\"programs\": [...]}); left as it is")
          System.halt(1)
      end

    {:error, :enoent} ->
      {%{}, []}
  end

if File.exists?(box_file) do
  stamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")
  # two runs in one second must not overwrite the first one's copy
  bak =
    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(fn 0 -> "#{box_file}.bak-#{stamp}"; n -> "#{box_file}.bak-#{stamp}-#{n}" end)
    |> Enum.find(&(not File.exists?(&1)))

  File.cp!(box_file, bak)
end

# one program a line, as Poca's README writes it
programs = kept ++ rows
others = box |> Map.delete("programs") |> Enum.map(fn {k, v} -> "  #{JSON.encode!(k)}: #{JSON.encode!(v)},\n" end)

text =
  "{\n" <>
    Enum.join(others) <>
    "  \"programs\": [\n" <>
    Enum.map_join(programs, ",\n", &("    " <> JSON.encode!(&1))) <>
    "\n  ]\n}\n"

File.mkdir_p!(config_dir)
File.write!(box_file, text)

IO.puts("tezcatlipoca setup: wrote #{length(rows)} rows into #{box_file} (#{length(kept)} of yours kept)")
IO.puts("  tezcatl      pages :4001, relay :4100 (Poca's secret); files and terminals under #{fs_root}")
IO.puts("  xipe_totec   :4200 -- choose its project once first: #{Path.join(bundle, "xipe_totec/bin/xipe")} choice project <path>")

if emacs do
  IO.puts("  emacs        #{emacs} --fg-daemon, emacs-vent from #{vent} on :4000")
  IO.puts("               (needs the websocket package in that Emacs: M-x package-install RET websocket)")
else
  IO.puts("  emacs        none (--no-emacs): start your own Emacs with emacs-vent on :4000")
end

IO.puts("Then: tezcatlipoca start, open box (Ctrl+Shift+B), start the rows, and open http://127.0.0.1:4001/main.html")
