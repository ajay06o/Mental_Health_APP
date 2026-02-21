"""
Alembic-style migration template to create `audit_logs` table.

This is a standalone template—if you use Alembic, copy the contents
into a normal Alembic revision file (in versions/) and run `alembic upgrade head`.
"""
from alembic import op
import sqlalchemy as sa


def upgrade():
    op.create_table(
        'audit_logs',
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('user_id', sa.Integer, nullable=False),
        sa.Column('action', sa.String(100), nullable=False),
        sa.Column('details', sa.Text, nullable=True),
        sa.Column('timestamp', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade():
    op.drop_table('audit_logs')
