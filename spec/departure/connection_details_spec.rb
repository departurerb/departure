require 'spec_helper'

describe Departure::ConnectionDetails do
  let(:connection_details) { described_class.new(connection_data) }

  around do |example|
    ClimateControl.modify(env_var) do
      example.run
    end
  end

  describe '#to_s' do
    subject { connection_details.to_s }

    let(:env_var) { {} }
    let(:connection_data) do
      {
        host: 'foo.com',
        user: 'root',
        database: 'dummy_test'
      }
    end

    context 'when the port is not specified' do
      let(:connection_data) { { user: 'root', database: 'dummy_test' } }

      it { is_expected.to include("-P #{Departure::ConnectionDetails::DEFAULT_PORT}") }
    end

    context 'when the port is specified in the connection data' do
      let(:connection_data) { { user: 'root', database: 'dummy_test', port: 213 } }

      it { is_expected.to include('-P 213') }
      it { is_expected.to_not include('-S ') }
    end

    context 'when the host is not specified' do
      let(:env_var) { { PERCONA_DB_HOST: nil } }
      let(:connection_data) { { user: 'root', database: 'dummy_test' } }

      it { is_expected.to include('-h "localhost"') }
      it { is_expected.to_not include('-S ') }
    end

    context 'when the socket is specified in the connection data' do
      let(:connection_data) { { socket: '/tmp/database.sock' } }

      it { is_expected.to include('-S /tmp/database.sock') }
      it { is_expected.to_not include('-h ') }
      it { is_expected.to_not include('-P ') }
    end

    context 'when the socket and host is specified in the connection data' do
      let(:connection_data) { { socket: '/tmp/database.sock', host: '127.0.0.1' } }

      it { is_expected.to include('-S /tmp/database.sock') }
      it { is_expected.to_not include('-h ') }
      it { is_expected.to_not include('-P ') }
    end

    context 'when the host is specified' do
      let(:env_var) { { PERCONA_DB_HOST: nil } }
      let(:connection_data) do
        { host: 'foo.com:3306', user: 'root', database: 'dummy_test' }
      end

      it { is_expected.not_to include('-h localhost') }
      it { is_expected.to include('-h "foo.com:3306"') }

      context 'when ssl ca is specified' do
        let(:connection_data) do
          { host: 'foo.com:3306', user: 'root', database: 'dummy_test', sslca: '~/test.pem' }
        end

        it { is_expected.to include('-h "foo.com:3306;mysql_ssl=1;mysql_ssl_client_ca=~/test.pem"') }
      end
    end

    context 'when specifying PERCONA_DB_HOST' do
      let(:env_var) { { PERCONA_DB_HOST: 'foo.com:3306' } }

      it { is_expected.to include('h "foo.com:3306"') }
    end

    context 'when specifying PERCONA_DB_USER' do
      let(:env_var) { { PERCONA_DB_USER: 'percona' } }

      it { is_expected.to include('-u percona') }
    end

    context 'when specifying PERCONA_DB_PASSWORD' do
      let(:env_var) { { PERCONA_DB_PASSWORD: 'password' } }

      it { is_expected.to include('--password password') }
    end

    context 'when specifying PERCONA_SOCKET' do
      let(:env_var) { { PERCONA_SOCKET: '/tmp/database.sock' } }

      it { is_expected.to include('-S /tmp/database.sock') }
      it { is_expected.to_not include('-h ') }
      it { is_expected.to_not include('-P ') }
    end

    context 'when specifying PERCONA_SOCKET and PERCONA_HOST' do
      let(:env_var) { { PERCONA_SOCKET: '/tmp/database.sock', PERCONA_HOST: '127.0.0.1' } }

      it { is_expected.to include('-S /tmp/database.sock') }
      it { is_expected.to_not include('-h ') }
      it { is_expected.to_not include('-P ') }
    end

    context 'when the password contains bash incompatible characters' do
      let(:env_var) { { PERCONA_DB_PASSWORD: nil } }
      let(:connection_data) { { password: '!#/PASSWORD!!!' } }

      it { is_expected.to include('--password \!\#/PASSWORD\!\!\!') }
    end
  end

  describe '#database' do
    subject { connection_details.database }

    let(:connection_data) do
      {
        host: 'localhost',
        user: 'root',
        database: 'dummy_test'
      }
    end

    context 'when specifying PERCONA_DB_NAME' do
      let(:env_var) { { PERCONA_DB_NAME: 'dummy_database' } }

      it { is_expected.to eq('dummy_database') }
    end
  end
end
