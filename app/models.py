from pydantic import BaseModel, Field


class ProviderRequest(BaseModel):
    name: str
    provider: str
    client_id: str
    client_secret: str
    provider_options: dict[str, str] = Field(
        default_factory=dict
    )
