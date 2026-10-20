import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';

void main() {
  test('POS filter does not silently change selected restaurant scope', () {
    final state = OwnerState();
    state.availableRestaurants = ['Working', 'Warehouse', 'Undetermined'];
    state.restaurantIdsByName = {
      'Working': 'rest-1',
      'Warehouse': 'rest-2',
      'Undetermined': 'rest-3',
    };
    state.restaurantPosStatusByName.addAll({
      'Working': 'with_pos',
      'Warehouse': 'without_pos',
      'Undetermined': 'unknown',
    });
    state.selectedRestaurants = state.availableRestaurants.toSet();
    state.setRestaurantListFilter('with_pos');
    expect(state.visibleRestaurantNames, ['Working']);
    expect(state.selectedRestaurants.length, 3,
        reason: 'Visual filtering must not silently change the report scope');

    state.chooseOnlyRestaurantsWithPos();
    expect(state.selectedRestaurantIds, {'rest-1'});
    expect(state.selectedRestaurants, {'Working'});

    state.setRestaurantListFilter('all');
    expect(state.visibleRestaurantNames.length, 3);
    state.setRestaurantListFilter('unknown');
    expect(state.visibleRestaurantNames, ['Undetermined']);
    state.dispose();
  });

  test('unknown POS topology cannot silently force empty selection', () {
    final state = OwnerState();
    state.availableRestaurants = ['One'];
    state.restaurantIdsByName = {'One': 'rest-1'};
    state.selectedRestaurants = {'One'};
    state.chooseOnlyRestaurantsWithPos();
    expect(state.selectedRestaurantIds, {'rest-1'});
    state.dispose();
  });
}
