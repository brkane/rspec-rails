require 'rspec/rails/feature_check'

module ExampleAppHooks
  DEFAULT_SOURCE_PATH = File.expand_path('..', __FILE__)

  module AR
    def source_paths
      [DEFAULT_SOURCE_PATH]
    end

    def setup_tasks
      # no-op
    end

    def final_tasks
      copy_file 'spec/verify_active_record_spec.rb'
      run('bin/rake db:migrate')
      if ::Rails::VERSION::STRING.to_f < 4.1
        run('bin/rake db:migrate RAILS_ENV=test')
      end
    end
  end

  module NoAR
    def source_paths
      [File.join(DEFAULT_SOURCE_PATH, 'no_active_record')]
    end

    def setup_tasks
      copy_file 'app/models/in_memory/model.rb'
      copy_file 'lib/rails/generators/in_memory/model/model_generator.rb'
      copy_file 'lib/rails/generators/in_memory/model/templates/model.rb.erb'
      application <<-CONFIG
        config.generators do |g|
          g.orm :in_memory, :migration => false
        end
      CONFIG
    end

    def final_tasks
      copy_file 'spec/verify_no_active_record_spec.rb'
    end
  end

  def self.environment_hooks
    if defined?(ActiveRecord)
      AR
    else
      NoAR
    end
  end
end

def generate(*)
  super
  $?.success? || abort
end

# Generally polluting `main` is bad as it monkey patches all objects. In this
# context, `self` is an _instance_ of a `Rails::Generators::AppGenerator`. So
# this won't pollute anything.
extend ExampleAppHooks.environment_hooks

setup_tasks

generate('rspec:install')
generate('controller wombats index') # plural
generate('controller welcome index') # singular
generate('integration_test widgets')
generate('mailer Notifications signup')
if ::RSpec::Rails::FeatureCheck.has_action_mailer_preview?
  create_file "spec/support/default_preview_path.rb", <<-EOS.strip_heredoc
    ENV['RAILS_ENV'] = 'development'

    CONFIG_PATH = File.expand_path('../../../config',  __FILE__)
    APP_PATH = File.expand_path(File.join(CONFIG_PATH, 'application'))
    # Default rails setup
    require File.join(CONFIG_PATH, 'boot')
    require 'rails/all'
    require File.join(CONFIG_PATH, 'environment')

    puts Rails.application.config.action_mailer.preview_path
  EOS
  create_file "spec/verify_mailer_preview_path_spec.rb", <<-EOS.strip_heredoc
    RSpec.describe 'Verifying the railtie sets the preview path' do
      it 'is set to the rspec path' do
        exec_script = File.expand_path(
          File.join(__FILE__, '../support/default_preview_path.rb')
        )
        expect(%x(ruby #\{exec_script\}).chomp).to eq(
          "#\{::Rails.root\}/spec/mailers/previews"
        )
      end
    end
  EOS
end
generate('model thing name:string')
generate('helper things')
generate('scaffold widget name:string category:string instock:boolean foo_id:integer bar_id:integer --force')
generate('observer widget') if ::Rails::VERSION::STRING.to_f < 4.0
generate('scaffold gadget') # scaffold with no attributes
generate('scaffold admin/account name:string') # scaffold with nested resource
generate('rspec:feature gadget')
generate('controller things custom_action')

begin
  require 'active_job'
  generate('job upload_backups')
rescue LoadError
end

file "app/views/things/custom_action.html.erb",
     "This is a template for a custom action.",
     :force => true

gsub_file 'spec/spec_helper.rb', /^=(begin|end)/, ''

# Warnings are too noisy in the sample apps
gsub_file 'spec/spec_helper.rb',
          'config.warnings = true',
          'config.warnings = false'
gsub_file '.rspec', '--warnings', ''

final_tasks
