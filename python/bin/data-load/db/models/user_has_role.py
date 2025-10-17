import sqlalchemy as sa
from typing import TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from db.models.user import User
    from db.models.role import Role


class UserHasRole(Base):
    __tablename__ = "user_has_role"

    user_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.BigInteger, sa.ForeignKey("user.id"), primary_key=True
    )
    role_id: sa.orm.Mapped[int] = sa.orm.mapped_column(
        sa.BigInteger, sa.ForeignKey("role.id"), primary_key=True
    )

    # Relationships
    ## many_to_one
    user: sa.orm.Mapped["User"] = sa.orm.relationship(
        "User", uselist=False, back_populates="user_has_roles"
    )
    ## many_to_one
    role: sa.orm.Mapped["Role"] = sa.orm.relationship(
        "Role", uselist=False, back_populates="role_has_users"
    )

    def __repr__(self):
        return f"UserHasRole(user={self.user.id}, role={self.role.id})"
