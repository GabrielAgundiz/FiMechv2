import 'package:flutter/material.dart';
import 'package:fimech/screens/user/citeform.dart';
import 'package:fimech/screens/user/widgets/cancelled.dart';
import 'package:fimech/screens/user/widgets/completed.dart';
import 'package:fimech/screens/user/widgets/upcoming.dart';
import 'package:fimech/router.dart';

class SchedulePage extends StatefulWidget {
  final bool showReturnButton; // si true, muestra el botón para regresar al formulario
  const SchedulePage({super.key, this.showReturnButton = false});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with RouteAware {
  int _buttonIndex = 0;

  // Devuelve nuevas instancias para forzar refresco cuando se hace setState
  List<Widget> get _scheduleWidgets => [
        UpcomingSchedule(),
        CompletedSchedule(),
        CancelledSchedule(),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    // La pantalla fue empujada
    setState(() {});
  }

  @override
  void didPopNext() {
    // Volvimos a esta pantalla desde otra; refrescar
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text(
          'Citas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: widget.showReturnButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Regresa al formulario de cita (navega hacia atrás a la pantalla anterior)
                  Navigator.pop(context);
                },
              )
            : null,
        // Título de la barra de aplicación
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 20,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Text(
                  "Calendario",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Container(
                padding: const EdgeInsets.all(5),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                height: 56, // Altura fija para el contenedor que contiene los botones.
                width: MediaQuery.of(context).size.width,
                child: Row(
                  children: [
                    // Cada opción ocupa 1/3 del ancho total
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _buttonIndex = 0),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _buttonIndex == 0 ? Colors.green[300] : Colors.grey[100],
                          ),
                          child: Text(
                            'Próximas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _buttonIndex == 0 ? Colors.black : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _buttonIndex = 1),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _buttonIndex == 1 ? Colors.green[300] : Colors.grey[100],
                          ),
                          child: Text(
                            'Completadas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _buttonIndex == 1 ? Colors.black : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _buttonIndex = 2),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _buttonIndex == 2 ? Colors.green[300] : Colors.grey[100],
                          ),
                          child: Text(
                            'Canceladas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _buttonIndex == 2 ? Colors.black : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              _scheduleWidgets[_buttonIndex],
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: Colors.green[300],
          onPressed: () async {
            // Abrir el formulario y esperar el resultado. Si devuelve true,
            // significa que el formulario guardó una cita y cerró con pop(true).
            final result = await Navigator.push<bool?>(
              context,
              MaterialPageRoute(
                builder: (context) => const CiteForm(workshopData: {}),
              ),
            );
            // Si el formulario indicó que guardó la cita, refrescar la pantalla
            // para actualizar la lista de citas. Esto devuelve a la misma
            // instancia de SchedulePage, por lo que la bottom navigation se
            // mantiene visible.
            if (result == true) {
              setState(() {});
            }
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}
