package Plugins::MQTTEvents::Plugin;

use strict;
use warnings;
use base qw(Slim::Plugin::Base);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Control::Request;

our $VERSION = '0.7';

my $prefs = preferences('plugin.mqttevents');
my $log;

sub initPlugin {
    my $class = shift;

    # Initialize Log
    $log = Slim::Utils::Log->addLogCategory({
        'category'     => 'plugin.mqttevents',
        'defaultLevel' => 'INFO',
        'description'  => 'PLUGIN_MQTTEVENTS_NAME',
    });

    $prefs->init({
        broker_host => 'localhost',
        broker_port => 1883,
        username    => '',
        password    => '',
        base_topic  => 'lms',
        retain      => 0,
    });

    # Check dependency
    eval {
        require Net::MQTT::Simple;
        $ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
    };

    if ($@) {
        $log->error("Net::MQTT::Simple is missing!");
        return;
    }

    $class->SUPER::initPlugin();

    if (main::WEBUI) {
        require Plugins::MQTTEvents::Settings;
        Plugins::MQTTEvents::Settings->new();
    }

    # Use the anonymous wrapper logic learned from SqueezeESP32
    Slim::Control::Request::subscribe( sub { handleNotification(@_) }, [['power']] );
    Slim::Control::Request::subscribe( sub { handleNotification(@_) }, [['mixer']] );

    # Use the root logger to ensure this prints during the boot sequence (not working)
    # Slim::Utils::Log::logger('')->info("MQTTEvents Plugin v$VERSION initialized and subscribed.");
    # $log->info("MQTTEvents Plugin v$VERSION initialized and subscribed.");
}

sub getDisplayName { return 'PLUGIN_MQTTEVENTS_NAME'; }
sub needsClient { return 0; }

sub handleNotification {
    my $request = shift;
    my $client   = $request->client() || return;
    
    $log->debug("Notification: " . $request->getRequestString());

    my $mac = $client->id() || return;
    $mac =~ s/://g; # Strip colons for Topic/Player usage

    my $base = $prefs->get('base_topic') || 'lms';
    my ($topic, $value, $key);

    if ($request->isCommand([['power']])) {
        my $power = $request->getParam('_newvalue');
        $topic = "$base/$mac/power";
        $value = defined $power ? ($power ? 1 : 0) : 0;
        $key   = 'power';
    }
    elsif ($request->isCommand([['mixer'],['volume']])) {
        $topic = "$base/$mac/mixer/volume";
        $value = int($client->volume());
        $key   = 'volume';
    }
    elsif ($request->isCommand([['mixer'],['muting']])) {
        my $mute = $request->getParam('_newvalue');
        $topic = "$base/$mac/mixer/muting";
        $value = defined $mute ? ($mute ? 1 : 0) : 0;
        $key   = 'muting';
    }

    if (defined $topic) {
        $log->debug("Publishing $key=$value to $topic");
        _publish($topic, $mac, $key, $value);
    }
}

sub _publish {
    my ($topic, $player, $key, $value) = @_;

    my $host   = $prefs->get('broker_host') || 'localhost';
    my $port   = $prefs->get('broker_port') || 1883;
    my $user   = $prefs->get('username');
    my $pass   = $prefs->get('password');
    my $retain = $prefs->get('retain') || 0;

    my $broker  = "$host:$port";
    my $payload = qq({"player":"$player", "key":"$key", "value":$value});

    eval {
        require Net::MQTT::Simple;
        my $mqtt = Net::MQTT::Simple->new($broker);
        $mqtt->login($user, $pass) if $user;

        if ($retain) {
            $mqtt->retain($topic => $payload);
        } else {
            $mqtt->publish($topic => $payload);
        }
        undef $mqtt;
    };

    if ($@) {
        $log->error("MQTT publish failed: $@");
    }
}

sub shutdownPlugin {
    # No-op
}

1;
