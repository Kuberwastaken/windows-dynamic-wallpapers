import unittest
from convert_heic import validate_schedule


class ScheduleTests(unittest.TestCase):
    def test_sorts_valid_frame_schedule(self):
        self.assertEqual(validate_schedule([{'i': 1, 't': .75}, {'i': 0, 't': 0}], 2),
                         [{'i': 0, 't': 0}, {'i': 1, 't': .75}])

    def test_rejects_unsafe_or_ambiguous_schedules(self):
        cases = [[], [{'i': -1, 't': .5}], [{'i': 2, 't': .5}],
                 [{'i': 0, 't': 1}], [{'i': 0, 't': float('nan')}],
                 [{'i': True, 't': .5}], [{'i': 0, 't': .5}, {'i': 1, 't': .5}]]
        for entries in cases:
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                validate_schedule(entries, 2)


if __name__ == '__main__':
    unittest.main()
