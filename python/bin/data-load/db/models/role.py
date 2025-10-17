from typing import Optional, TYPE_CHECKING
import sqlalchemy as sa

from .base import Base

if TYPE_CHECKING:
    from db.models.user_has_role import UserHasRole


class Role(Base):
    __tablename__ = "role"

    id: sa.orm.Mapped[int] = sa.orm.mapped_column(sa.BigInteger, primary_key=True)
    role: sa.orm.Mapped[str] = sa.orm.mapped_column(sa.String(15), nullable=False)

    # Relationships
    ## one-to-many
    role_has_users: sa.orm.Mapped[Optional[list["UserHasRole"]]] = sa.orm.relationship(
        "UserHasRole", back_populates="role"
    )

    def __repr__(self):
        return f"Role(id={self.id}, role='{self.role}')"
