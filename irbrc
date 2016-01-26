require 'rubygems' unless defined? Gem
%w{hirb interactive_editor fancy_irb awesome_print}.each do |gem|
  begin
    require "#{gem}"
  rescue
    system("gem install #{gem}")
  end
end

FancyIrb.start :colorize => {
  :rocket_prompt => [:blue],
  :result_prompt => [:blue],
  :input_prompt  => nil,
  :irb_errors    => [:red],
  :stderr        => [:red, :bright],
  :stdout        => [:white],
  :input         => nil,
  :output        => true,
}

Hirb.enable
AwesomePrint.irb!
