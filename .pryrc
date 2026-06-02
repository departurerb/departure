if defined?(PryByebug)
  Pry.commands.alias_command "c", "continue"
  Pry.commands.alias_command "s", "step"
  Pry.commands.alias_command "n", "next"
  Pry.commands.alias_command "f", "finish"
  Pry.commands.alias_command "w", "pry-backtrace"

  Pry::Commands.command(/^$/, "repeat last command") do
    pry_instance.run_command Pry.history.to_a.last
  end
end
