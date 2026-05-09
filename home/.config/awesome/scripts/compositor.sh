#!/bin/bash

if [[ "$XDG_SESSION_TYPE" != "wayland" ]]; then
	picom
fi
