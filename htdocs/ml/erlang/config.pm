#--------------------------------------------------------------------------
# ezmlm-www (configuration file - see README)
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
#-- Mailing list configuration goes here:
push @$lists, {
	name => 'erlang@erlang-users.jp',
	local_part => 'erlang',
	host_part => 'erlang-users.jp',
	description => 'Erlang Users  mailing list',
	archive => Mail::Ezmlm::Archive->new('/usr/local/var/ezmlm/erlang/erlang'),
	conceal_senders => 1,
	subscription_info => 1,
	descending_by_default => 1,
	default_sorting => 'thread',   #may be 'thread', 'date' or 'subject'
	show_html => 1,
	highlight => 1,
	show_inline_images => 1
};

# 
# To add more lists, just copy-and-paste the previous block
#?as many times as many lists you have.
#
# push @$lists, {
# 	name => 'another-list@example.com',
# 	local_part => 'another-list',
# 	host_part => 'example.com',
# 	description => 'My second list',
# 	archive => Mail::Ezmlm::Archive->new('/path/to/other/list/directory'),
# 	conceal_senders => 1,
# 	subscription_info => 1,
# 	descending_by_default => 1
#	default_sorting => 'thread',   #may be 'thread', 'date' or 'subject'
#	show_html => 1,
#	highlight => 1,
#	show_inline_images => 1
# };
# 

#---------------------------------------------------------------------------
#-- This option specifies the language used for localized strings:

$lang = 'en';

#---------------------------------------------------------------------------
#-- To enable vpopmail support just uncomment the following line:
#-- (this will disable the configuration done with the "push @$lists"
#-- syntax above, as all information will be taken from vpopmail local
#-- database and the %Config defaults below.)

#use vpopmail;


#---------------------------------------------------------------------------
#--Additional configuration options:

%Config = (
	ListServerName => 'List Server',

	#--These settings will be used for vpopmail-based mailing lists:
	DefaultVpopmailSettings => {
		conceal_senders => 1,
		subscription_info => 1,
		descending_by_default => 1,
		default_sorting => 'thread',   #may be 'thread', 'date' or 'subject'
		show_html => 1,
		highlight => 1
	},
	VpopmailAccess => {
		default_policy => 'allow',
		allow_lists => [],
		deny_lists => [],
		allow_domains => [],
		deny_domains => []
	},
	
	#--CSS web path:
	CSSPath => '../style.css'
);


1;
