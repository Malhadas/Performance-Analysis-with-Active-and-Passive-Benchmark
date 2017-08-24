#!/usr/bin/dtrace -s
#pragma D option quiet

dtrace:::BEGIN {
	printf("\n");
	printf("\tInstrumentador para IOzone\n");
	printf("\t-------------------------");

	self->ok         = 0;
	self->teste      = 1;
	self->kb_read    = 0;
	self->kb_write   = 0;
	self->time_read  = 0;
	self->time_write = 0;
	self->time_close = 0;

	self->read  = 0;
	self->write = 0;

	total_kb   = 0;
	total_time = 0;
	self->time_init  = 0;
}

syscall::openat*:entry {
	self->fd = arg1;
}

syscall::openat*:return
/self->fd/ {
	self->ok = (strstr(copyinstr(self->fd), $$1) != NULL) ? 1 : 0;
}

syscall::read*:entry
/self->ok/ {
	self->kb_read   = self->kb_read  + (arg2/1024);
	
	self->time_init = timestamp;
}

syscall::read*:return
/self->ok && arg1/ {
	self->time_read = self->time_read + ((timestamp - self->time_init));
}

syscall::write*:entry
/self->ok/ {
	self->kb_write  = self->kb_write + (arg2/1024);

	self->time_init = timestamp;
}

syscall::write*:return
/self->ok && arg1/ {
	self->time_write = self->time_write + ((timestamp - self->time_init));
}

syscall::close*:return
/(self->kb_read>0 || self->kb_write>0) && self->ok/ {

	kb         = self->kb_write+self->kb_read;
    total_kb   = total_kb + kb;
	time       = self->time_read + self->time_write;
	total_time = total_time + time;
	kbr        = self->kb_read;
	kbw        = self->kb_write;

	printf("\n");
	printf("  -----------------------------------------------------------------------------------------------\n");
	printf(" /      Test File Closed     \n");
	printf("|       ----------------     \n");
    printf("| %s\n", $$2);
	printf("|%5s|%15s|%15s|%15s|%16s|%17s|%20s|\n", "Test", "KB", "KB Read", "KB Write", "Time Spent", "Time Read", "Time Write");
	printf("|%5d|%15d|%15d|%15d|%16d|%17d|%20d|\n", self->teste, kb, kbr, kbw, time, self->time_read, self->time_write);
	printf("|\n");
	printf(" \\\n");
	printf("  -----------------------------------------------------------------------------------------------\n"); 

	self->ok         = 0;
	self->teste      = self->teste +1;
	self->time_init  = 0;
	self->kb_read    = 0;
	self->kb_write   = 0;
    self->fd         = 0;
	self->time_read  = 0;
	self->time_write = 0;
}

dtrace:::END {

	printf(" ---------------------------------------\n");
	printf("| DTrace stoped.                        |\n");
	printf(" ---------------------------------------\n");
	printf("| Total Time spent: %20d|\n", total_time);
	printf("| Total KB:         %20d|\n", total_kb);
	printf(" ---------------------------------------\n\n");
}
