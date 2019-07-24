require 'spec_helper_acceptance'

describe 'managing java truststores', unless: UNSUPPORTED_PLATFORMS.include?(os[:family]) do

  def keystore_command(target, pass = 'puppet')
    command = "\"#{@keytool_path}keytool\" -list -v -keystore #{target} -storepass #{pass}"
    command.prepend("& ") if os[:family] == "windows"
    command
  end

  # rubocop:disable RSpec/InstanceVariable : Instance variables are inherited and thus cannot be contained within lets
  include_context 'common variables'

  let(:target){"#{@target_dir}truststore.ts"}

  it 'ensures the working directory is clean' do
    run_shell("#{@remove_command} #{target}") do |r|
      expect(r.exit_code).to be_zero
    end
  end

  it 'creates a truststore' do
    pp = <<-EOS
      java_ks { 'puppetca:truststore':
        ensure       => #{@ensure_ks},
        certificate  => "#{@temp_dir}ca.pem",
        target       => "#{target}",
        password     => 'puppet',
        trustcacerts => true,
        path         => #{@resource_path},
    }
    EOS
    idempotent_apply(pp)
  end

  expectations = [
    %r{Your keystore contains 1 entry},
    %r{Alias name: puppetca},
    %r{CN=Test CA},
  ]
  it 'verifies the truststore' do
    run_shell((keystore_command target), expect_failures: true) do |r|
      expect(r.exit_code).to be_zero
      expectations.each do |expect|
        expect(r.stdout).to match(expect)
      end
    end
  end

  it 'recreates a truststore if password fails' do
    pp = <<-MANIFEST
      java_ks { 'puppetca:truststore':
        ensure              => latest,
        certificate         => "#{@temp_dir}ca.pem",
        target              => "#{target}",
        password            => 'bobinsky',
        password_fail_reset => true,
        trustcacerts        => true,
        path                => #{@resource_path},
    }
    MANIFEST
    idempotent_apply(pp)
  end

  it 'verifies the truststore again' do
    run_shell((keystore_command(target, 'bobinsky')), expect_failures: true) do |r|
      expect(r.exit_code).to be_zero
      expectations.each do |expect|
        expect(r.stdout).to match(expect)
      end
    end
  end
end
