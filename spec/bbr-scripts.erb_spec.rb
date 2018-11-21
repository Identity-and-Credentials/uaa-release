require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'spec_helper'

describe 'bosh backup and restore script' do
  let(:properties) {
    {
      'links' => {
        'uaa_db' => {
          'instances' => [],
          'properties' => {
            'release_level_backup' => true,
            'uaadb' => {
              'address' => '127.0.0.1',
              'port' => 5432,
              'db_scheme' => 'postgresql',
              'databases' => [{'name' => 'uaa_db_name', 'tag' => 'uaa'}],
              'roles' => [{'name' => 'admin', 'password' => 'example', 'tag' => 'admin'}]
            }
          }
        }
      },
      'properties' => {
          'release_level_backup' => true,
          'uaa' => {
              'limitedFunctionality' => {
                  'statusFile' => '/var/vcap/data/uaa/bbr_limited_mode.lock'
              }
          },
          'uaadb' => {
              'address' => '127.0.0.2',
              'port' => 2222,
              'db_scheme' => 'postgres',
              'databases' => [{'name' => 'uaa_db_2_name', 'tag' => 'uaa'}],
              'roles' => [{'name' => 'ad2min', 'password' => 'exam2ple', 'tag' => 'admin'}]
          }
      }
    }
  }
  let(:generated_script) {
    binding = Bosh::Template::EvaluationContext.new(properties, nil).get_binding
    generated_script = ERB.new(File.read(script)).result(binding)
  }

  context 'release_level_backup is true' do
    describe 'pre-backup-lock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/pre-backup-lock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include("touch '/var/vcap/data/uaa/bbr_limited_mode.lock'")
        expect(generated_script).to include('  enable_limited_functionality')
        expect(generated_script).to include('sleep 6')
      end
    end

    describe 'pre-restore-lock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/pre-restore-lock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('/var/vcap/bosh/bin/monit stop uaa')
        expect(generated_script).to include('sleep 15')
      end
    end

    describe 'post-restore-unlock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/post-restore-unlock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('/var/vcap/bosh/bin/monit start uaa')
        expect(generated_script).to include('/var/vcap/jobs/uaa/bin/post-start')
        expect(generated_script).to include('sleep 40')
      end
    end

    describe 'post-backup-lock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/post-backup-unlock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include("rm -f '/var/vcap/data/uaa/bbr_limited_mode.lock'")
        expect(generated_script).to include('  disable_limited_functionality')
        expect(generated_script).to include('sleep 6')
      end
    end

    describe 'backup.sh.erb' do
      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/backup.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('JOB_PATH="/var/vcap/jobs/bbr-uaadb"')
        expect(generated_script).to include('BBR_ARTIFACT_FILE_PATH="${BBR_ARTIFACT_DIRECTORY}/uaadb-artifact-file"')
        expect(generated_script).to include('CONFIG_PATH="${JOB_PATH}/config/config.json"')
        expect(generated_script).to include('"/var/vcap/jobs/database-backup-restorer/bin/backup" --config "${CONFIG_PATH}" --artifact-file "${BBR_ARTIFACT_FILE_PATH}"')
      end
    end

    describe 'config.json.erb' do
      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/config.json.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('"username": "admin"')
        expect(generated_script).to include('"password": "example"')
        expect(generated_script).to include('"host": "127.0.0.1"')
        expect(generated_script).to include('"port": 5432')
        expect(generated_script).to include('"database": "uaa_db_name"')
        expect(generated_script).to include('"adapter": "postgres"')
      end
    end

    describe 'config.json when properties are used instead of links' do
      before(:each) do
        properties['links'] = nil
      end

      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/config.json.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('"username": "ad2min"')
        expect(generated_script).to include('"password": "exam2ple"')
        expect(generated_script).to include('"host": "127.0.0.2"')
        expect(generated_script).to include('"port": 2222')
        expect(generated_script).to include('"database": "uaa_db_2_name"')
        expect(generated_script).to include('"adapter": "postgres"')
      end
    end

    describe 'restore.sh.erb' do
      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/restore.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('JOB_PATH="/var/vcap/jobs/bbr-uaadb"')
        expect(generated_script).to include('BBR_ARTIFACT_FILE_PATH="${BBR_ARTIFACT_DIRECTORY}/uaadb-artifact-file"')
        expect(generated_script).to include('CONFIG_PATH="${JOB_PATH}/config/config.json"')
        expect(generated_script).to include('"/var/vcap/jobs/database-backup-restorer/bin/restore" --config "${CONFIG_PATH}" --artifact-file "${BBR_ARTIFACT_FILE_PATH}"')
      end
    end
  end


  context 'release_level_backup is false' do

    before(:each) do
      properties['links']['uaa_db']['properties']['release_level_backup'] = false
      properties['properties']['release_level_backup'] = false
    end

    describe 'pre-backup-lock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/pre-backup-lock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).not_to include("touch '/var/vcap/data/uaa/bbr_limited_mode.lock'")
        expect(generated_script).not_to include('enable_limited_functionality')
        expect(generated_script).not_to include('sleep 6')
      end
    end

    describe 'pre-restore-lock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/pre-restore-lock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).not_to include('/var/vcap/bosh/bin/monit stop uaa')
        expect(generated_script).not_to include('sleep 15')
      end
    end

    describe 'post-restore-unlock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/post-restore-unlock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).not_to include('/var/vcap/bosh/bin/monit start uaa')
        expect(generated_script).not_to include('/var/vcap/jobs/uaa/bin/post-start')
        expect(generated_script).not_to include('sleep 15')
      end
    end

    describe 'post-backup-unlock.erb' do
      let(:script) { "#{__dir__}/../jobs/uaa/templates/bbr/post-backup-unlock.sh.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).not_to include("rm -f '/var/vcap/data/uaa/bbr_limited_mode.lock'")
        expect(generated_script).not_to include('disable_limited_functionality')
        expect(generated_script).not_to include('sleep 6')
      end
    end

    describe 'backup.sh.erb' do
      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/backup.sh.erb" }

      it 'does not have the backup command' do
        expect(generated_script).to include('JOB_PATH="/var/vcap/jobs/bbr-uaadb"')
        expect(generated_script).to include('BBR_ARTIFACT_FILE_PATH="${BBR_ARTIFACT_DIRECTORY}/uaadb-artifact-file"')
        expect(generated_script).to include('CONFIG_PATH="${JOB_PATH}/config/config.json"')
        expect(generated_script).not_to include('"/var/vcap/jobs/database-backup-restorer/bin/backup" --config "${CONFIG_PATH}" --artifact-file "${BBR_ARTIFACT_FILE_PATH}"')
      end
    end

    describe 'config.json.erb' do
      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/config.json.erb" }

      it 'it has all the expected lines' do
        expect(generated_script).to include('"username": "admin"')
        expect(generated_script).to include('"password": "example"')
        expect(generated_script).to include('"host": "127.0.0.1"')
        expect(generated_script).to include('"port": 5432')
        expect(generated_script).to include('"database": "uaa_db_name"')
        expect(generated_script).to include('"adapter": "postgres"')
      end
    end

    describe 'restore.sh.erb' do
      let(:script) { "#{__dir__}/../jobs/bbr-uaadb/templates/restore.sh.erb" }

      it 'does not have the restore command' do
        expect(generated_script).to include('JOB_PATH="/var/vcap/jobs/bbr-uaadb"')
        expect(generated_script).to include('BBR_ARTIFACT_FILE_PATH="${BBR_ARTIFACT_DIRECTORY}/uaadb-artifact-file"')
        expect(generated_script).to include('CONFIG_PATH="${JOB_PATH}/config/config.json"')
        expect(generated_script).not_to include('"/var/vcap/jobs/database-backup-restorer/bin/restore" --config "${CONFIG_PATH}" --artifact-file "${BBR_ARTIFACT_FILE_PATH}"')
      end
    end
  end

end
