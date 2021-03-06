/*
 * input.c
 * This file is part of LCDd, the lcdproc server.
 *
 * This file is released under the GNU General Public License. Refer to the
 * COPYING file distributed with this package.
 *
 * Copyright 	(c) 1999, William Ferrell, Scott Scriven
 *		(c) 2001, 2002, Rene Wagner
 *
 *
 * Handles keypad (and other?) input from the user.
 */

/*

  Currently, the keys are as follows:

  Context     Key      Function
  -------     ---      --------
  Normal               "normal" context is handled in this source file.
              A        Pause/Continue
              B        Back(Go to previous screen)
              C        Forward(Go to next screen)
              D        Open main menu
              E-Z      Sent to client, if any; ignored otherwise

 (menu keys are not handled here, but in the menu code)
  Menu
              A        Enter/select
              B        Up/Left
              C        Down/Right
              D        Exit/Cancel
              E-Z      Ignored
*/


#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "shared/sockets.h"
#include "shared/report.h"

#include "drivers/lcd.h"
#include "drivers.h"

#include "client_data.h"
#include "clients.h"
#include "screen.h"
#include "widget.h"
#include "screenlist.h"
#include "menus.h"

#include "input.h"

#define KeyWanted(a,b)	((a) && strchr((a), (b)))
#define CurrentScreen	screenlist_current
#define FirstClient(a)	(client *)LL_GetFirst(a);
#define NextClient(a)	(client *)LL_GetNext(a);

int server_input (int key);

int freepausekey = DEFAULT_FREEPAUSEKEY;
int freebackkey = DEFAULT_FREEBACKKEY;
int freeforwardkey = DEFAULT_FREEFORWARDKEY;
int freemainmenukey = DEFAULT_FREEMAINMENUKEY;

/* FIXME!  The server tends to crash when "E" is pressed..  (?!)
 * (but only when the joystick driver is the last one on the list...)
 */

/* Checks for keypad input, and dispatches it*/
int
handle_input ()
{
	char str[15];
	int key;
	screen *s;
	/*widget *w;*/
	client *c;

	if ((key = drivers_getkey ()) == 0)
		return 0;

	/*debug (RPT_DEBUG, "handle_input(%c)", (char) key);*/

	/* Sequence:
	 * 	Does the current screen want the key?
	 * 	IfTrue: Let the current screen handle it
	 * 	IfFalse:
	 * 	    Let the first client that wants the key handle it
	 * 	Finally let the server handle all key presses, too
	 */

	/* NOTE: The INPUT_* keys (A,B,C,D) should only be requested
	 *       by a screen or client to be informed when a key is
	 *       pressed e.g. to enter the server menu.
	 *       Those keys should not be used to really cause the
	 *       client to do something useful.
	 */

	/* TODO:  Interpret and translate keys!*/

	/* Give current screen a shot at the key first*/
	s = CurrentScreen ();

	if ( s && (KeyWanted(s->keys, key)) ) {
		/* This screen wants this key.  Tell it we got one*/
		snprintf(str, sizeof(str), "key %c\n", key);
		sock_send_string(s->parent->sock, str);
		/* The server gets this key as well*/
	}

	else {
		/* Give the key to the first client that wants it*/

		c = FirstClient(clients);

		while (c) {
			/* If the client wants this keypress...*/
			if(KeyWanted(c->data->client_keys,key)) {
				/* Send keypress to client*/
				snprintf(str, sizeof(str), "key %c\n", key);
				sock_send_string(c->sock, str);
				break;	/* first come, first serve*/
			};
			c = NextClient(clients);
		} /* while clients*/
	}

	/* Give server a shot at all keys */
	server_input (key);

	return 0;
}

int
server_input (int key)
{
	debug (RPT_INFO, "server_input(%c)", (char) key);
	report(RPT_INFO, "key %d pressed on device", key);

	switch ((char) key) {
		case INPUT_PAUSE_KEY:
			if (!freepausekey) {
				if (screenlist_action == SCR_HOLD)
					screenlist_action = 0;
				else
					screenlist_action = SCR_HOLD;
			}
			break;
		case INPUT_BACK_KEY:
			if (!freebackkey) {
				screenlist_action = SCR_BACK;
				screenlist_prev ();
			}
			break;
		case INPUT_FORWARD_KEY:
			if (freeforwardkey==0) {
				screenlist_action = SCR_SKIP;
				screenlist_next ();
			}
			break;
		case INPUT_MAIN_MENU_KEY:
			if (freemainmenukey==0) {
				debug (RPT_DEBUG, "got the menu key!");
				server_menu ();
			}
			break;
		default:
			debug (RPT_DEBUG, "server_input: Unused key \"%c\" (%i)", (char) key, key);
			break;
	}

	return 0;
}
