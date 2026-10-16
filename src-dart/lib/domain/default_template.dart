import '../localization/app_strings.dart';
import 'models.dart';

ObservationTemplate makeDemoTemplate(AppStrings strings) {
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
    attribute(strings.text('default_attribute_behavior'), <String>[
      strings.text('default_behavior_fights'),
      strings.text('default_behavior_symbolic_fights'),
      strings.text('default_behavior_chase'),
      strings.text('default_behavior_tickling'),
      strings.text('default_value_other_feminine'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_affectivity'), <String>[
      strings.text('default_affectivity_negative'),
      strings.text('default_affectivity_positive'),
      strings.text('default_affectivity_neutral'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_interaction'), <String>[
      strings.text('default_interaction_unilateral'),
      strings.text('default_interaction_reciprocal'),
      strings.text('default_value_other_feminine'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_contact'), <String>[
      strings.text('default_contact_without'),
      strings.text('default_contact_with'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_force'), <String>[
      strings.text('default_force_low'),
      strings.text('default_force_unspecified'),
      strings.text('default_force_high'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_movements'), <String>[
      strings.text('default_movement_direct'),
      strings.text('default_movement_curved'),
      strings.text('default_value_other_masculine'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_pairs'), <String>[
      strings.text('default_pairs_one'),
      strings.text('default_pairs_two'),
      strings.text('default_pairs_three_or_more'),
      strings.text('default_value_not_applicable'),
    ]),
    attribute(strings.text('default_attribute_gender'), <String>[
      strings.text('default_gender_same'),
      strings.text('default_gender_opposite'),
      strings.text('default_gender_mixed'),
      strings.text('default_value_not_applicable'),
    ]),
  ];

  return ObservationTemplate(
    id: 'fb52dd46-85cc-4864-b11e-44b8a5b28331',
    name: strings.text('default_template_name'),
    intervalMs: 15000,
    nextAttributeId: nextAttributeId,
    nextValueId: nextValueId,
    attributes: attributes,
  );
}

Database makeDefaultDatabase(AppStrings strings) =>
    Database(templates: <ObservationTemplate>[makeDemoTemplate(strings)]);
