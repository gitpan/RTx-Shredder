package RTx::Shredder::Constants;

require Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter);

use constant {
	DEPENDS_ON	=> 0x000001,
	WIPE_AFTER	=> 0x000010,
};

use constant {
	ON_STACK	=> 0x00000,
	WIPED		=> 0x00001,
};

our @EXPORT = qw(
		DEPENDS_ON
		WIPE_AFTER
		ON_STACK
		WIPED
		);

1;
