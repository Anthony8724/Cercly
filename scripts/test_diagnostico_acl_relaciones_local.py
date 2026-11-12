#!/usr/bin/env python3
"""Regresiones sin respaldo, SQL remoto ni datos de usuarios."""
import copy
import json
import unittest

from diagnostico_acl_relaciones_local import compare_relation_acl, relation_security_diagnostic


class AclDiagnosticTest(unittest.TestCase):
    def setUp(self):
        self.entry = dict(schema='extensions', name='fixture', grantor='supabase_admin',
                          grantee='postgres', privilege_type='SELECT', is_grantable=True)
        self.catalog = dict(relations=[dict(schema='extensions', name='fixture', owner='supabase_admin')],
                            relation_acl=[self.entry], column_acl=[], policies=[])

    def test_equal(self):
        self.assertTrue(compare_relation_acl([self.entry], [dict(self.entry)])['same_entries_including_multiplicity'])

    def test_order_only(self):
        rows = [self.entry, dict(self.entry, grantee='PUBLIC')]
        result = compare_relation_acl(rows, list(reversed(rows)))
        self.assertTrue(result['order_only'])
        self.assertFalse(result['same_order'])
        self.assertEqual(result['different_relations'], [])

    def test_missing_grant(self):
        result = compare_relation_acl([self.entry], [])
        self.assertEqual(result['missing_entries'], [dict(entry=self.entry, count=1)])
        self.assertFalse(result['order_only'])

    def test_additional_grant(self):
        result = compare_relation_acl([], [self.entry])
        self.assertEqual(result['additional_entries'][0]['entry'], self.entry)

    def test_each_security_attribute_matters(self):
        for key, value in dict(schema='vault', name='other', grantor='postgres', grantee='anon',
                               privilege_type='UPDATE', is_grantable=False).items():
            with self.subTest(attribute=key):
                result = compare_relation_acl([self.entry], [dict(self.entry, **{key: value})])
                self.assertFalse(result['same_entries_including_multiplicity'])
                self.assertEqual(len(result['missing_entries']), 1)
                self.assertEqual(len(result['additional_entries']), 1)

    def test_duplicate_not_discarded(self):
        self.assertFalse(compare_relation_acl([self.entry], [self.entry, self.entry])['same_entries_including_multiplicity'])

    def test_unknown_attribute_not_discarded(self):
        self.assertFalse(compare_relation_acl([self.entry], [dict(self.entry, extra=True)])['same_entries_including_multiplicity'])

    def test_wrong_types_not_equivalent(self):
        for value in [1, 'true', None]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                compare_relation_acl([dict(self.entry, is_grantable=value)], [self.entry])

    def test_missing_attribute_rejected(self):
        entry = dict(self.entry)
        del entry['grantor']
        with self.assertRaises(ValueError):
            compare_relation_acl([entry], [self.entry])

    def test_empty_explicit_inventory_does_not_claim_default_equivalence(self):
        empty = dict(self.catalog, relation_acl=[])
        detail = json.loads(relation_security_diagnostic(empty, empty))
        self.assertTrue(any('NULL/default' in limit for limit in detail['coverage_limits']))

    def test_pre_and_post_owner_and_exact_rows_survive_serialization(self):
        before = copy.deepcopy(self.catalog)
        before['relations'][0]['owner'] = 'cercly_restore_operator_12345678'
        before['relation_acl'] = [dict(self.entry, grantor='cercly_restore_operator_12345678')]
        target = copy.deepcopy(self.catalog)
        target['relation_acl'] = []
        storage = [dict(schema='extensions', name='fixture', raw_acl='{}', default_acl='fixture')]
        detail = json.loads(relation_security_diagnostic(self.catalog, target, before, storage))
        self.assertEqual(detail['source'], self.catalog)
        self.assertEqual(detail['restored'], target)
        self.assertEqual(detail['before_owner_recovery'], before)
        self.assertEqual(detail['target_acl_storage_after_owner'], storage)
        self.assertEqual(detail['acl_comparison']['missing_entries'][0]['entry'], self.entry)
        self.assertFalse(detail['owner_change_acl_comparison']['same_entries_including_multiplicity'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
