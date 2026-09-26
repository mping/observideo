import 'models.dart';

ObservationTemplate makeDemoTemplate() {
  var nextValueId = 1;
  var nextAttributeId = 1;

  ObservationAttribute attribute(String name, List<String> names) =>
      ObservationAttribute(
        id: nextAttributeId++,
        name: name,
        values: names
            .map((value) => ObservationValue(id: nextValueId++, name: value))
            .toList(),
      );

  final attributes = <ObservationAttribute>[
    attribute('Comportamento', <String>[
      'Lutas (murros, pontapés, deitar ao chão, empurrar, ...)',
      'Lutas com componente simbólica (super heróis, bons e maus, ...)',
      'Perseguição',
      'Cócegas',
      'Outra',
      'N/A',
    ]),
    attribute('Afetividade', <String>['Negativa', 'Positiva', 'Neutra', 'N/A']),
    attribute('Interação', <String>['Unilateral', 'Recíproca', 'Outra', 'N/A']),
    attribute('Contacto', <String>['Sem contacto', 'Com contacto', 'N/A']),
    attribute('Força', <String>[
      'Pouca força',
      'Força indiferenciada',
      'Muita força',
      'N/A',
    ]),
    attribute('Movimentos', <String>[
      'Diretos',
      'Curvilíneos',
      'Outros',
      'N/A',
    ]),
    attribute('Pares', <String>['1', '2', '3 ou mais', 'N/A']),
    attribute('Género', <String>['Mesmo', 'Oposto', 'Misto', 'N/A']),
  ];

  return ObservationTemplate(
    id: 'fb52dd46-85cc-4864-b11e-44b8a5b28331',
    name: 'Observação BLP',
    intervalMs: 15000,
    nextAttributeId: nextAttributeId,
    nextValueId: nextValueId,
    attributes: attributes,
  );
}

Database makeDefaultDatabase() =>
    Database(templates: <ObservationTemplate>[makeDemoTemplate()]);
