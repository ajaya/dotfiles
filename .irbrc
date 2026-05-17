IRB.conf[:SAVE_HISTORY] = 10000
Reline::Face.config(:completion_dialog) do |conf|
  conf.define :default, foreground: :white, background: :black
  conf.define :enhanced, foreground: :black, background: :white
  conf.define :scrollbar, foreground: :white, background: :black
end

local_irbrc = File.expand_path("~/.irbrc.local")
load local_irbrc if File.readable?(local_irbrc)
