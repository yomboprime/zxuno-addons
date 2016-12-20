# veripac9
El procesador interpretado del cartucho Videopac-9, implementado como un subprocesador del ZX Spectrum.


El bus externo se conecta a la memoria interna, donde se da preferencia al maestro de bus externo frente al uso interno.

A la vez, la ejecución de la soft-cpu está multiplexada en el tiempo con el uso de la señal step, de forma que el z80 puede detener la ejecución y proceder a leer o escribir.

Todos los registros están mapeados en el espacio de memoria interna:

MAPA DE MEMORIA

00 - C9: bytes de ram

CA: Control:
	En lectura da el estado de la máquina:
	bits 1,0: estado de la UC:
		0: fetch
		1: fetch 2
		2: ejecución
		3: halt
	bit 2: buzzer (1 ó 0)

CB: Registro de escritura de la tecla pulsada. Hay además un flipflop interno para saber cuando ha habido una tecla nueva.

CC: acumulador

CD: program counter

CE: registro de instruccion

CF: data counter

D0 - EF: Buffer de pantalla 32 bytes (2 lineas 16 caracteres)

F0 - FF: 16 registros

---------

ADICIONES / MODIFICACIONES A LA MAQUINA

202 bytes de ram en lugar de 100

números hexadecimales 0 a FF o sea de 0 a 255 decimal

Instrucciones nuevas: por determinar los opcodes no usados.
