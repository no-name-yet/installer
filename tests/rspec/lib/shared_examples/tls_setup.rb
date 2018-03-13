# frozen_string_literal: true

require 'fileutils'
require 'tls_certs'

RSpec.shared_examples 'withTLSSetup' do |domain|
  before(:all) do
    smoke_platform_dir = if @tfvars_file.platform == 'metal'
                           'bare-metal'
                         else
                           @tfvars_file.platform
                         end
    test_folder = File.join(ENV['RSPEC_PATH'], '..')
    generate_tls("#{test_folder}/smoke/#{smoke_platform_dir}/user_provided_tls/certs/", @name, domain)

    root_folder = File.join(ENV['RSPEC_PATH'], '../..')
    custom_tls_tf = "#{test_folder}/smoke/#{smoke_platform_dir}/user_provided_tls/tls.tf"
    dest_folder = "#{root_folder}/platforms/#{@tfvars_file.platform}"
    original_tls_tf = "#{dest_folder}/tls.tf"

    FileUtils.mv(original_tls_tf, "#{dest_folder}/tls.tf.original")
    FileUtils.cp(custom_tls_tf, dest_folder)
  end
end
