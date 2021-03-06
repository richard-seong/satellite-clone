#!/usr/bin/ruby

require 'shellwords'

@username = "admin"
@password = "changeme"

def prepare_hammer_cmd(command)
  "hammer -u #{@username.shellescape} -p #{@password.shellescape} #{command}"
end

def run_hammer_cmd(command)
  command = prepare_hammer_cmd(command)
  `#{command}`
end

def get_info_from_hammer(command, column=1)
  bash_parse = " | grep -v \"Warning:\" | tail -n+2 | awk -F, {'print $#{column}'}"
  run_hammer_cmd(command + bash_parse)
end

external_capsules = []
external_capsule_ids = get_info_from_hammer("--csv capsule list --search 'feature = \"Pulp Node\"'")
if external_capsule_ids.empty?
  STDOUT.puts "There are no external capsules to disassociate."
else
  external_capsule_ids.split("\n").each do |id|
    lifecycle_environment = get_info_from_hammer("--csv capsule content lifecycle-environments --id #{id}").split("\n")
    name = get_info_from_hammer("--csv capsule info --id #{id}", 2).chomp
    external_capsules << {:id => id, :name => name, :lifecycle_environments => lifecycle_environment}
  end


  reverse_commands = []
  external_capsules.each do |capsule|
    capsule[:lifecycle_environments].each do |env|
      run_hammer_cmd("--csv capsule content remove-lifecycle-environment --id #{capsule[:id]} --environment-id #{env}")
      reverse_command = prepare_hammer_cmd("--csv capsule content add-lifecycle-environment --id #{capsule[:id]} --environment-id #{env}")
      reverse_commands << reverse_command
    end
  end

  STDOUT.puts "All Capsules are unassociated with any lifecycle environments. This is to avoid any syncing errors with your original Satellite " \
              "and any interference with existing infrastructure. To reverse these changes, run the following commands," \
              " making sure to replace the credentials with your own."
  reverse_commands.each do |reverse|
    STDOUT.puts reverse
  end
end
