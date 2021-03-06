package Rest::Competition::Qual;

use strict;
use warnings;

use parent 'Plack::App::RESTMy';

use MIME::Base64;

use HTTP::Exception qw(3XX);
use HTTP::Exception qw(4XX);
use HTTP::Exception qw(5XX);

use Store::Qual;

use utf8;

use open IO => ':encoding(utf8)';

use YAML::Syck;
$YAML::Syck::ImplicitUnicode = 1;

sub GET {
	my ($self, $env, $id) = @_;

	my $login = $env->{'psgix.session'}{user_id};
	HTTP::Exception::403->throw(message=>"Forbidden") unless $login;
	my $login_info = $self->auth->getUser($env, $login);

	my $userid = $env->{'rest.userid'};
	my $compid = $env->{'rest.competitionid'};

	if ($userid){
		my $user;
		if (defined $login_info->{admin} || $userid eq $login){
			$user = $self->qual->getUser($env, $userid);
		}

		if ($user){
			return $user;
		}else{
			HTTP::Exception::404->throw(message=>"Not found");
		}
	}else{

		my $users = [];
		if ($login_info->{admin}){
			$users = $self->qual->getAllUsers($env);
		}else{
			$users = $self->qual->getAllUsers($env,{login=>$login});
		}
		
		my $link = (); my $count;
		my $qualFee; my $registred; my $user_list;
		my $judge;
		foreach my $u (@$users) {
			my $user_info = $self->auth->getUser($env, $u->{login});
			push (@$user_list, {
				href => $self->refToUrl($env, 'Rest::Competition::Qual::UserId', {'rest.userid'=>($u->{login}||'')}),
				login => $u->{login},
				video => $u->{video},
				points => $u->{points},
				pointsA => $u->{pointsA},
				pointsB => $u->{pointsB},
				overallA => $u->{overallA},
				pointsA_j => $u->{pointsA_j},
				pointsA_j_norep => $u->{pointsA_j_norep},
				pointsB_j => $u->{pointsB_j},
				judge => $u->{judge},
				reserved => $u->{reserved}
			});
			push (@$link, {
				href => $self->refToUrl($env, 'Rest::Competition::Qual::UserId', {'rest.userid'=>($u->{login}||'')}),
				title => $u->{login}.' - '.$u->{points},
				rel => 'Rest::Competition::Qual::UserId'
			});
			$count->{$user_info->{sex}}{$user_info->{category}}++;
			$count->{$user_info->{sex}}{$user_info->{shirt}}++;
			$judge->{judged}{suma}++ if $u->{judge};
			$judge->{reserved}{suma}++ if $u->{reserved};
			$judge->{judged}{$u->{judge}}++ if $u->{judge};
			$judge->{reserved}{$u->{reserved}}++ if $u->{reserved};
		}
		$count->{count} = scalar @$users;
	
		return {link => $link, count=>$count, judge_count=>$judge, users=>$user_list};
	}
}

sub POST {
	my ($self, $env, $params, $data) = @_;

	if (!$data || ref $data ne 'HASH'){
		HTTP::Exception::400->throw(message=>"Bad request");
	}

	### Clean email
	my $login = $data->{login};

	### Check if usr exists
	if (!$self->auth->checkUserExistence($env, $login)){
		HTTP::Exception::400->throw(message=>"User doesn't exist");
	}
	my $user = $self->auth->getUser($env, $login);
	if (!$user->{registred}){
		HTTP::Exception::400->throw(message=>"User doesn't exist");
	}
	if ($self->qual->checkUserExistence($env, $login)){
		HTTP::Exception::400->throw(message=>"Qual for user exists");
	}else{
		my $send = delete $data->{send};

		### Create user
		my $id = $self->qual->addUser($env, $login, $data );

		### Check if user created
		if (!$id){
			HTTP::Exception::500->throw(message=>"Can't add qual for user.");
		}
		if($send){
			### Send email
			my $mail = Mail->new( $self->const );
			open FILE, $self->const->get("EmailQual");
			my $msg;
			foreach (<FILE>){
				$msg .= $_;
			}

			# BULK_EMAIL {{athlete.firstName}} {{athlete.lastName}} {{athlete.email}} {{athlete.phone}} {{athlete.bDay}} {{athlete.category}} {{athlete.sex}} {{athlete.shirt}}
			my $rtrn = $mail->sendMail({
				merge_keys => [qw(BULK_EMAIL {{athlete.firstName}} {{athlete.lastName}} {{athlete.email}} {{athlete.phone}} {{athlete.bDay}} {{athlete.category}} {{athlete.sex}} {{athlete.shirt}} {{athlete.gym}})],
				list => [
					join("::", $login, $user->{firstName}, $user->{lastName}, $login, $user->{phone}, $user->{bDay}, $user->{category}, $user->{sex}, $user->{shirt}, $user->{gym}),
					join("::", $self->const->get("EmailBcc"), $user->{firstName}, $user->{lastName}, $login, $user->{phone}, $user->{bDay}, $user->{category}, $user->{sex}, $user->{shirt}, $user->{gym}),
				],
				from => $self->const->get("EmailBcc"),
				subject => 'FM2016 qualification',
				message => $msg
			});
			if (!$rtrn){
				my $id = $self->auth->updateUser($env, $login, {'$set' => {emailStatus=>0}});
			}
		}
		### Return ok
		return { qual => $id };
	}

	return { qual => undef };
}

sub PUT {
	my ($self, $env, $params, $data) = @_;

	my $userid = $env->{'rest.userid'};
	return HTTP::Exception::405->throw(message=>"Bad request") unless $userid;

	if ($data->{login} ne $userid){
		HTTP::Exception::400->throw(message=>"Login can't be changed. Drop and create new qual.");
	}

	### Update user data
	$self->qual->updateUser($env, $userid, { '$set' => $data });
	return $data
}

sub DELETE {
	my ($self, $env, $params, $data) = @_;

	my $userid = $env->{'rest.userid'};
	return HTTP::Exception::405->throw(message=>"Bad request") unless $userid;

	my $ret = $self->qual->removeUser($env, $userid);

	return $ret;
}

### Return form for gray pages
sub GET_FORM {
	my ($class, $env, $content, $par) = @_;

	if ($env->{'rest.userid'}){
		return {
			get => undef,
			delete => {
				params => {}
			},
			put => {
				params => {
					DATA => {
						type => 'textarea',
						name => 'DATA',
						default => $content
					}
				}
			}
		}
	}else{
		return {
			get => undef,
			post => {
				default => "---\nlogin: email"."\nvideo: url"."\npoints: number"."\npointsA: number"."\npointsB: number"
			},
		}
	}
}

1;