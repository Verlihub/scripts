#!/usr/bin/python
# coding: latin-1

# ForceMove 0.0.1.0
# © 2021 RoLex

from thread import start_new_thread
from time import sleep
import socket

host = ""
port = [411, 6000]
move = "piter.feardc.net"
show = False

def serv (_host, _port, _move, _show):
	sock = socket.socket (socket.AF_INET, socket.SOCK_STREAM)
	sock.setsockopt (socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	sock.bind ((_host, _port))
	sock.listen (10)

	while 1:
		conn, addr = sock.accept ()

		if _show:
			print "Connect:", addr

		conn.sendall ("$ForceMove " + _move + "|")
		conn.close ()
		sleep (0.01)

def main ():
	global host, port, move, show

	for num in port:
		start_new_thread (serv, (host, num, move, show,))

		if show:
			print "Listen:", (host, num)

	while 1:
		sleep (0.01)

main ()

# end of file