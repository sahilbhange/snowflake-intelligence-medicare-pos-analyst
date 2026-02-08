"""
AI Observability Implementation for Semantic Analyst Validation
Snowflake Intelligence Medicare POS Analyst Project

This module instruments the Cortex Analyst with AI Observability for:
- Automated quality evaluation (relevance, groundedness, context)
- Execution tracing (input → semantic model → SQL → results)
- A/B testing of semantic model versions
- Regression testing with eval seeds
"""

from trulens.core import TruSession, instrument, Select
from trulens.apps.basic import TruApp
from trulens.providers.cortex import Cortex
from snowflake.snowpark import Session
from typing import Dict, List, Any
import json


# ============================================================================
# 1. SETUP & CONFIGURATION
# ============================================================================

def initialize_session() -> tuple[Session, TruSession]:
    """
    Initialize Snowflake and TruLens sessions.

    Returns:
        tuple: (Snowflake Session, TruLens Session)
    """
    # Snowflake connection
    connection_params = {
        'account': 'your_account',
        'user': 'your_user',
        'password': 'your_password',
        'role': 'ANALYST_ROLE',
        'warehouse': 'COMPUTE_WH',
        'database': 'MEDICARE_POS',
        'schema': 'INTELLIGENCE'
    }

    snowflake_session = Session.builder.configs(connection_params).create()

    # TruLens session with Snowflake event table
    tru_session = TruSession(
        connector=snowflake_session,
        event_table='INTELLIGENCE.AI_OBSERVABILITY_EVENTS'
    )

    return snowflake_session, tru_session


# ============================================================================
# 2. INSTRUMENTED SEMANTIC ANALYST
# ============================================================================

class SemanticAnalyst:
    """
    Cortex Analyst wrapper with AI Observability instrumentation.
    """

    def __init__(self, session: Session, semantic_model_stage: str, version: str):
        """
        Args:
            session: Snowflake Snowpark session
            semantic_model_stage: Stage path (e.g., '@ANALYTICS.CORTEX_SEM_MODEL_STG')
            version: Model version (e.g., 'v1.3.2')
        """
        self.session = session
        self.semantic_model_stage = semantic_model_stage
        self.version = version
        self.model_file = f"{semantic_model_stage}/{version}.yaml"

    @instrument(span_type='RETRIEVAL')
    def get_semantic_context(self, question: str) -> List[str]:
        """
        Retrieve relevant semantic model definitions for the question.

        Maps to:
        - RETRIEVAL.QUERY_TEXT: question
        - RETRIEVAL.RETRIEVED_CONTEXTS: returned descriptions

        Args:
            question: User's natural language question

        Returns:
            List of relevant measure/dimension descriptions
        """
        # Query semantic model metadata for relevant context
        query = f"""
        SELECT
            measure_name,
            description
        FROM INTELLIGENCE.SEMANTIC_MODEL_METADATA
        WHERE description ILIKE '%{question}%'
           OR measure_name ILIKE '%{question}%'
        LIMIT 5
        """

        results = self.session.sql(query).collect()
        contexts = [f"{r['MEASURE_NAME']}: {r['DESCRIPTION']}" for r in results]

        return contexts if contexts else ["No relevant semantic context found"]

    @instrument(span_type='GENERATION')
    def generate_sql(self, question: str, contexts: List[str]) -> Dict[str, Any]:
        """
        Generate SQL using Cortex Analyst.

        Args:
            question: User question
            contexts: Retrieved semantic contexts

        Returns:
            dict: {'sql': str, 'results': list, 'metadata': dict}
        """
        # Construct Cortex Analyst request
        request = {
            'messages': [
                {
                    'role': 'user',
                    'content': [
                        {'type': 'text', 'text': question}
                    ]
                }
            ],
            'semantic_model_file': self.model_file
        }

        # Call Cortex Analyst
        query = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'cortex-analyst',
            {json.dumps(request)}
        ) AS response
        """

        result = self.session.sql(query).collect()[0]
        response = json.loads(result['RESPONSE'])

        return {
            'sql': response.get('sql', ''),
            'results': response.get('results', []),
            'metadata': {
                'model_version': self.version,
                'contexts_used': len(contexts)
            }
        }

    @instrument(span_type='RECORD_ROOT')
    def query(self, question: str) -> Dict[str, Any]:
        """
        Main entry point: question → contexts → SQL → results.

        This is the root span that contains retrieval and generation as children.

        Args:
            question: User's natural language question

        Returns:
            dict: Complete response with SQL, results, and metadata
        """
        # Step 1: Retrieve semantic context
        contexts = self.get_semantic_context(question)

        # Step 2: Generate SQL
        response = self.generate_sql(question, contexts)

        # Step 3: Execute SQL and verify
        execution_status = self._execute_sql(response['sql'])

        return {
            'question': question,
            'contexts': contexts,
            'sql': response['sql'],
            'results': response['results'],
            'metadata': {
                **response['metadata'],
                'execution_success': execution_status['success'],
                'execution_error': execution_status.get('error')
            }
        }

    def _execute_sql(self, sql: str) -> Dict[str, Any]:
        """
        Execute generated SQL to verify correctness.

        Args:
            sql: Generated SQL query

        Returns:
            dict: {'success': bool, 'error': str | None}
        """
        try:
            self.session.sql(sql).collect()
            return {'success': True, 'error': None}
        except Exception as e:
            return {'success': False, 'error': str(e)}


# ============================================================================
# 3. EVALUATION METRICS
# ============================================================================

class SemanticAnalystEvaluator:
    """
    Defines evaluation metrics for semantic analyst quality.
    """

    def __init__(self, session: Session):
        """
        Args:
            session: Snowflake Snowpark session
        """
        self.cortex = Cortex(session, model_engine='llama3.1-70b')

    def answer_relevance(self, question: str, sql: str) -> float:
        """
        Measures if generated SQL addresses the user's question.

        Args:
            question: User question
            sql: Generated SQL

        Returns:
            Score from 0 (irrelevant) to 1 (highly relevant)
        """
        return self.cortex.relevance_with_cot_reasons(
            prompt=f"User asked: {question}",
            response=f"Generated SQL: {sql}"
        )

    def groundedness(self, semantic_yaml: str, sql: str) -> float:
        """
        Measures if SQL is grounded in the semantic model.

        Args:
            semantic_yaml: Semantic model YAML content
            sql: Generated SQL

        Returns:
            Score from 0 (hallucinated) to 1 (fully grounded)
        """
        return self.cortex.groundedness_measure_with_cot_reasons(
            source=semantic_yaml,
            statement=sql
        )

    def context_relevance(self, question: str, contexts: List[str]) -> float:
        """
        Measures if retrieved semantic contexts are relevant to question.

        Args:
            question: User question
            contexts: Retrieved semantic definitions

        Returns:
            Score from 0 (irrelevant) to 1 (highly relevant)
        """
        context_text = "\n".join(contexts)
        return self.cortex.qs_relevance_with_cot_reasons(
            question=question,
            context=context_text
        )

    def sql_execution_success(self, sql: str, session: Session) -> float:
        """
        Binary metric: Does SQL execute without errors?

        Args:
            sql: Generated SQL
            session: Snowflake session

        Returns:
            1.0 if successful, 0.0 if failed
        """
        try:
            session.sql(sql).collect()
            return 1.0
        except Exception:
            return 0.0


# ============================================================================
# 4. REGRESSION TESTING
# ============================================================================

def run_nightly_regression(
    session: Session,
    tru_session: TruSession,
    semantic_model_stage: str,
    version: str
) -> Dict[str, Any]:
    """
    Run automated regression tests on eval seeds.

    Args:
        session: Snowflake session
        tru_session: TruLens session
        semantic_model_stage: Stage path
        version: Model version to test

    Returns:
        dict: Summary statistics
    """
    # Initialize analyst and evaluator
    analyst = SemanticAnalyst(session, semantic_model_stage, version)
    evaluator = SemanticAnalystEvaluator(session)

    # Create TruApp
    app = TruApp(
        analyst.query,
        app_name='DMEPOS_SEMANTIC_ANALYST',
        app_version=version
    )

    # Load eval seeds
    eval_seeds = session.table('INTELLIGENCE.ANALYST_EVAL_SET').collect()

    results = {
        'total_tests': len(eval_seeds),
        'passed': 0,
        'failed': 0,
        'avg_relevance': 0.0,
        'avg_groundedness': 0.0,
        'avg_context': 0.0
    }

    # Run each eval seed
    for seed in eval_seeds:
        with app as recording:
            response = analyst.query(seed['QUESTION'])

        # Evaluate (asynchronous, results stored in event table)
        # Metrics computed by Cortex LLM judge

    # Query results from event table
    stats = session.sql(f"""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN answer_relevance_score >= 0.7 THEN 1 ELSE 0 END) AS passed,
            AVG(answer_relevance_score) AS avg_relevance,
            AVG(groundedness_score) AS avg_groundedness,
            AVG(context_relevance_score) AS avg_context
        FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
        WHERE app_name = 'DMEPOS_SEMANTIC_ANALYST'
          AND app_version = '{version}'
          AND event_timestamp > DATEADD(hour, -1, CURRENT_TIMESTAMP())
    """).collect()[0]

    results.update({
        'passed': stats['PASSED'],
        'failed': stats['TOTAL'] - stats['PASSED'],
        'avg_relevance': round(stats['AVG_RELEVANCE'], 3),
        'avg_groundedness': round(stats['AVG_GROUNDEDNESS'], 3),
        'avg_context': round(stats['AVG_CONTEXT'], 3)
    })

    return results


# ============================================================================
# 5. A/B TESTING
# ============================================================================

def compare_semantic_model_versions(
    session: Session,
    tru_session: TruSession,
    semantic_model_stage: str,
    version_a: str,
    version_b: str,
    eval_seeds: List[str]
) -> Dict[str, Dict[str, float]]:
    """
    Compare two semantic model versions on same eval seeds.

    Args:
        session: Snowflake session
        tru_session: TruLens session
        semantic_model_stage: Stage path
        version_a: First version (e.g., 'v1.3.2')
        version_b: Second version (e.g., 'v1.4.0')
        eval_seeds: List of questions to test

    Returns:
        dict: Comparison metrics for both versions
    """
    results = {}

    for version in [version_a, version_b]:
        analyst = SemanticAnalyst(session, semantic_model_stage, version)
        app = TruApp(analyst.query, app_name='DMEPOS_SEMANTIC_ANALYST', app_version=version)

        # Run eval seeds
        for question in eval_seeds:
            with app as recording:
                analyst.query(question)

        # Aggregate results
        stats = session.sql(f"""
            SELECT
                AVG(answer_relevance_score) AS avg_relevance,
                AVG(groundedness_score) AS avg_groundedness,
                AVG(latency_ms) AS avg_latency,
                AVG(token_count) AS avg_tokens
            FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
            WHERE app_version = '{version}'
              AND event_timestamp > DATEADD(hour, -1, CURRENT_TIMESTAMP())
        """).collect()[0]

        results[version] = {
            'avg_relevance': stats['AVG_RELEVANCE'],
            'avg_groundedness': stats['AVG_GROUNDEDNESS'],
            'avg_latency_ms': stats['AVG_LATENCY'],
            'avg_tokens': stats['AVG_TOKENS']
        }

    return results


# ============================================================================
# 6. USAGE EXAMPLE
# ============================================================================

if __name__ == '__main__':
    # Initialize
    session, tru_session = initialize_session()

    # Example 1: Single query with tracing
    analyst = SemanticAnalyst(
        session=session,
        semantic_model_stage='@ANALYTICS.CORTEX_SEM_MODEL_STG',
        version='v1.3.2'
    )

    response = analyst.query("What are the top 5 states by DMEPOS claims?")
    print(f"SQL: {response['sql']}")
    print(f"Execution: {'✓' if response['metadata']['execution_success'] else '✗'}")

    # Example 2: Nightly regression
    regression_results = run_nightly_regression(
        session=session,
        tru_session=tru_session,
        semantic_model_stage='@ANALYTICS.CORTEX_SEM_MODEL_STG',
        version='v1.3.2'
    )
    print(f"Regression Results: {regression_results}")

    # Example 3: A/B test versions
    comparison = compare_semantic_model_versions(
        session=session,
        tru_session=tru_session,
        semantic_model_stage='@ANALYTICS.CORTEX_SEM_MODEL_STG',
        version_a='v1.3.2',
        version_b='v1.4.0',
        eval_seeds=[
            "Top 5 states by claims",
            "Average Medicare payment by HCPCS",
            "Total suppliers in California"
        ]
    )
    print(f"A/B Test: {comparison}")

    # Close session
    session.close()
