"""Regresión pura del creador Supabase de pg_stat_statements; sin conexión."""
import copy
import unittest
from recuperar_propietarios_relaciones_local import plan_relation_owner_recovery


class PgstatCreationOwnerTest(unittest.TestCase):
    def setUp(self):
        self.operator='cercly_restore_operator_1234abcd'
        self.ext=[dict(extname='pg_stat_statements',extversion='1.11',schema='extensions')]
        self.source=[dict(schema='extensions',name=name,relkind='v',relrowsecurity=False,
            relforcerowsecurity=False,owner='postgres') for name in ('pg_stat_statements','pg_stat_statements_info')]
        self.target=[dict(r,owner='supabase_admin') for r in self.source]
        self.members=[dict(schema=r['schema'],name=r['name'],extname='pg_stat_statements') for r in self.source]
        self.proof=dict(session_user=self.operator,current_user=self.operator,
            extension=dict(self.ext[0],owner='supabase_admin'),relations=copy.deepcopy(self.target))

    def plan(self,**changes):
        values=dict(source=self.source,restored=self.target,target_memberships=self.members,
            operator=self.operator,source_extensions=self.ext,restored_extensions=self.ext,
            pgstat_creation_evidence=self.proof)
        values.update(changes)
        return plan_relation_owner_recovery(**values)

    def test_original_rejection_without_creation_evidence(self):
        with self.assertRaisesRegex(ValueError,'UNEXPECTED_RELATION_OWNER'):
            self.plan(pgstat_creation_evidence=None)

    def test_exact_observed_creator_restores_only_archived_two_owners(self):
        plan=self.plan()
        self.assertEqual(plan['change_count'],2)
        self.assertEqual(plan['sql'].count('ALTER VIEW'),2)
        self.assertNotIn('GRANT',plan['sql'])
        self.assertTrue(plan['requires_full_acl_policy_verification'])

    def test_wrong_creator_proof_rejected(self):
        proof=copy.deepcopy(self.proof);proof['extension']['owner']='anon'
        with self.assertRaises(ValueError):self.plan(pgstat_creation_evidence=proof)

    def test_wrong_execution_identity_rejected(self):
        proof=copy.deepcopy(self.proof);proof['current_user']='supabase_admin'
        with self.assertRaises(ValueError):self.plan(pgstat_creation_evidence=proof)

    def test_missing_observed_relation_rejected(self):
        proof=copy.deepcopy(self.proof);proof['relations'].pop()
        with self.assertRaises(ValueError):self.plan(pgstat_creation_evidence=proof)

    def test_changed_observed_rls_rejected(self):
        proof=copy.deepcopy(self.proof);proof['relations'][0]['relrowsecurity']=True
        with self.assertRaises(ValueError):self.plan(pgstat_creation_evidence=proof)

    def test_wrong_extension_version_rejected(self):
        exts=[dict(self.ext[0],extversion='1.10')]
        with self.assertRaises(ValueError):self.plan(source_extensions=exts,restored_extensions=exts)

    def test_wrong_membership_rejected(self):
        members=[dict(m,extname='other') for m in self.members]
        with self.assertRaises(ValueError):self.plan(target_memberships=members)

    def test_unknown_relation_rejected_even_with_same_creator(self):
        source=[dict(self.source[0],name='not_reviewed')]
        target=[dict(source[0],owner='supabase_admin')]
        with self.assertRaises(ValueError):self.plan(source=source,restored=target)

    def test_real_rls_difference_rejected(self):
        target=copy.deepcopy(self.target);target[0]['relrowsecurity']=True
        with self.assertRaisesRegex(ValueError,'NON_OWNER_ATTRIBUTE_DIFFERENCE'):
            self.plan(restored=target)

    def test_arbitrary_owner_rejected(self):
        target=[dict(r,owner='anon') for r in self.target]
        with self.assertRaises(ValueError):self.plan(restored=target)

    def test_legacy_operator_creator_still_supported(self):
        plan=self.plan(restored=[dict(r,owner=self.operator) for r in self.target],pgstat_creation_evidence=None)
        self.assertEqual(plan['change_count'],2)

    def test_already_correct_is_noop(self):
        self.assertEqual(self.plan(restored=self.source)['change_count'],0)


if __name__=='__main__':unittest.main()
