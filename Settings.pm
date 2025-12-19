package Plugins::MQTTEvents::Settings;

use strict;
use warnings;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;
use Slim::Utils::Log;

BEGIN {
    $ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
}

my $prefs = preferences('plugin.mqttevents');
my $log;

sub new {
    my $class = shift;
    $log = Slim::Utils::Log->logger('plugin.mqttevents');
    $class->SUPER::new();
}

sub name {
    return Slim::Web::HTTP::CSRF->protectName('PLUGIN_MQTTEVENTS_NAME');
}

sub page {
    return Slim::Web::HTTP::CSRF->protectURI('plugins/MQTTEvents/settings.html');
}

sub prefs {
    return ($prefs, qw(broker_host broker_port username password base_topic retain));
}

sub handler {
    my ($class, $client, $params, $callback, @args) = @_;

    if ($params->{saveSettings}) {
        _save($params);
    }

    if ($params->{testConnection}) {
        my ($host, $port, $user, $pass, $base) = _collect_effective($params);
        my $ok = eval {
            require Net::MQTT::Simple;
            my $mqtt = Net::MQTT::Simple->new("$host:$port");
            $mqtt->login($user, $pass) if $user;
            $mqtt->publish(($base || 'lms') . '/_test' => '{"status":"ok","source":"LMS","action":"testConnection"}');
            1;
        };
        $params->{mqttevents_message} = $ok ? Slim::Utils::Strings::string('PLUGIN_MQTTEVENTS_TEST_OK') : "Test Failed: $@";
    }

    if ($params->{publishExamples}) {
        my ($host, $port, $user, $pass, $base, $retain) = _collect_effective($params);
        my $ok = eval {
            require Net::MQTT::Simple;
            my $mqtt = Net::MQTT::Simple->new("$host:$port");
            $mqtt->login($user, $pass) if $user;

            my $pub = sub {
                my ($t, $p) = @_;
                $retain ? $mqtt->retain($t => $p) : $mqtt->publish($t => $p);
            };

            my $root = $base || 'lms';
            $pub->("$root/_example/power",         '{"value":1}');
            $pub->("$root/_example/mixer/volume",  '{"value":27}');
            $pub->("$root/_example/mixer/muting",  '{"value":0}');
            undef $mqtt;
            1;
        };
        $params->{mqttevents_message} = $ok ? Slim::Utils::Strings::string('PLUGIN_MQTTEVENTS_EXAMPLES_PUBLISHED') : "Publish Failed: $@";
    }

    $params->{mqttevents_connected} = _check_connection($params);

    _reflect($params);
    return $class->SUPER::handler($client, $params);
}

# ---- helpers ----

sub _save {
    my ($params) = @_;
    my $base = $params->{pref_base_topic};
    $base = 'lms' if !defined $base || $base =~ /^\s*$/;

    for ($params->{pref_broker_host}, $params->{pref_broker_port}, $base) {
        s/^\s+// if defined; s/\s+$// if defined;
    }

    $prefs->set('broker_host', $params->{pref_broker_host} || 'localhost');
    $prefs->set('broker_port', int($params->{pref_broker_port} || 1883));
    $prefs->set('username',    $params->{pref_username} // '');
    $prefs->set('password',    $params->{pref_password} // '');
    $prefs->set('base_topic',  $base);
    $prefs->set('retain',      $params->{pref_retain} ? 1 : 0);
}

sub _reflect {
    my ($params) = @_;
    for my $k (qw(broker_host broker_port username password base_topic retain)) {
        $params->{"pref_$k"} = $prefs->get($k);
    }
}

sub _collect_effective {
    my ($params) = @_;
    my $host   = $params->{pref_broker_host} // $prefs->get('broker_host');
    my $port   = $params->{pref_broker_port} // $prefs->get('broker_port');
    my $user   = $params->{pref_username}    // $prefs->get('username');
    my $pass   = $params->{pref_password}    // $prefs->get('password');
    my $base   = $params->{pref_base_topic}  // $prefs->get('base_topic');
    my $retain = $params->{pref_retain}      // $prefs->get('retain');

    return ($host || 'localhost', int($port || 1883), $user, $pass, $base || 'lms', $retain ? 1 : 0);
}

sub _check_connection {
    my ($params) = @_;
    my ($host, $port, $user, $pass) = _collect_effective($params);

    return eval {
        require Net::MQTT::Simple;
        local $SIG{ALRM} = sub { die "timeout" };
        alarm(1);
        my $mqtt = Net::MQTT::Simple->new("$host:$port");
        $mqtt->login($user, $pass) if $user;
        alarm(0);
        return 1;
    } || 0;
}

1;
