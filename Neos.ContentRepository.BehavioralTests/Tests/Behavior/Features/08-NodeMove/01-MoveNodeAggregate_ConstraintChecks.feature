@contentrepository @adapters=DoctrineDBAL,Postgres
Feature: Move node to a new parent / within the current parent before a sibling / to the end of the sibling list

  As a user of the CR I want to move a node to a new parent / within the current parent before a sibling / to the end of the sibling list,
  without affecting other nodes in the node aggregate.

  These are the base test cases for the NodeAggregateCommandHandler to block invalid commands

  Content Structure:
  - lady-eleonode-rootford (Neos.ContentRepository:Root)
   - sir-david-nodenborough (Neos.ContentRepository.Testing:DocumentWithTetheredChildNode)
    - "tethered" nodewyn-tetherton (Neos.ContentRepository.Testing:Content)
    - sir-nodeward-nodington-iii (Neos.ContentRepository.Testing:Document)

  Background:
    Given using the following content dimensions:
      | Identifier | Values      | Generalizations |
      | market     | DE, CH      | CH->DE          |
      | language   | de, gsw, fr | gsw->de         |
    And using the following node types:
    """yaml
    'Neos.ContentRepository.Testing:Document': []
    'Neos.ContentRepository.Testing:AllowedContent': []
    'Neos.ContentRepository.Testing:Content':
      constraints:
        nodeTypes:
          '*': true
          'Neos.ContentRepository.Testing:Document': false
    'Neos.ContentRepository.Testing:DocumentWithTetheredChildNode':
      childNodes:
        tethered:
          type: 'Neos.ContentRepository.Testing:Content'
          constraints:
            nodeTypes:
              '*': true
              'Neos.ContentRepository.Testing:Content': false
    """
    And using identifier "default", I define a content repository
    And I am in content repository "default"
    And the command CreateRootWorkspace is executed with payload:
      | Key                  | Value                |
      | workspaceName        | "live"               |
      | workspaceTitle       | "Live"               |
      | workspaceDescription | "The live workspace" |
      | newContentStreamId   | "cs-identifier"      |
    And the graph projection is fully up to date
    And I am in content stream "cs-identifier" and dimension space point {"market":"DE", "language":"de"}
    And the command CreateRootNodeAggregateWithNode is executed with payload:
      | Key             | Value                         |
      | contentStreamId | "cs-identifier"               |
      | nodeAggregateId | "lady-eleonode-rootford"      |
      | nodeTypeName    | "Neos.ContentRepository:Root" |
    And the graph projection is fully up to date
    And the following CreateNodeAggregateWithNode commands are executed:
      | nodeAggregateId            | nodeName | parentNodeAggregateId  | nodeTypeName                                                 | tetheredDescendantNodeAggregateIds |
      | sir-david-nodenborough     | document | lady-eleonode-rootford | Neos.ContentRepository.Testing:DocumentWithTetheredChildNode | {"tethered": "nodewyn-tetherton"}  |
      | sir-nodeward-nodington-iii | esquire  | sir-david-nodenborough | Neos.ContentRepository.Testing:Document                      | {}                                 |
      | nodimus-prime | grandchild  | nodewyn-tetherton | Neos.ContentRepository.Testing:AllowedContent                      | {}                                 |

  Scenario: Try to move a node in a non-existing content stream:
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                    |
      | contentStreamId              | "non-existing"           |
      | nodeAggregateId              | "sir-david-nodenborough" |
      | relationDistributionStrategy | "scatter"                |
    Then the last command should have thrown an exception of type "ContentStreamDoesNotExistYet"

  Scenario: Try to move a node in a non-existing dimension space point:
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                                     |
      | contentStreamId              | "cs-identifier"                           |
      | nodeAggregateId              | "sir-david-nodenborough"                  |
      | dimensionSpacePoint          | {"market": "nope", "language": "neither"} |
      | relationDistributionStrategy | "scatter"                                 |
    Then the last command should have thrown an exception of type "DimensionSpacePointNotFound"

  Scenario: Try to move a node in a dimension space point the aggregate does not cover
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                              |
      | contentStreamId              | "cs-identifier"                    |
      | nodeAggregateId              | "sir-david-nodenborough"           |
      | dimensionSpacePoint          | {"market": "DE", "language": "fr"} |
      | relationDistributionStrategy | "scatter"                          |
    Then the last command should have thrown an exception of type "NodeAggregateDoesCurrentlyNotCoverDimensionSpacePoint"

  Scenario: Try to move a node of a non-existing node aggregate:
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value            |
      | contentStreamId              | "cs-identifier"  |
      | nodeAggregateId              | "i-do-not-exist" |
      | relationDistributionStrategy | "scatter"        |
    Then the last command should have thrown an exception of type "NodeAggregateCurrentlyDoesNotExist"

  Scenario: Try to move a node of a root node aggregate:
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                    |
      | contentStreamId              | "cs-identifier"          |
      | nodeAggregateId              | "lady-eleonode-rootford" |
      | relationDistributionStrategy | "scatter"                |
    Then the last command should have thrown an exception of type "NodeAggregateIsRoot"

  Scenario: Try to move a node of a tethered node aggregate:
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value               |
      | contentStreamId              | "cs-identifier"     |
      | nodeAggregateId              | "nodewyn-tetherton" |
      | relationDistributionStrategy | "scatter"           |
    Then the last command should have thrown an exception of type "NodeAggregateIsTethered"

  Scenario: Try to move existing node to a non-existing parent
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                            |
      | contentStreamId              | "cs-identifier"                  |
      | nodeAggregateId              | "sir-david-nodenborough"         |
      | newParentNodeAggregateId     | "non-existing-parent-identifier" |
      | relationDistributionStrategy | "scatter"                        |
    Then the last command should have thrown an exception of type "NodeAggregateCurrentlyDoesNotExist"

  Scenario: Try to move a node to a parent that already has a child node of the same name
    Given the command CreateNodeAggregateWithNode is executed with payload:
      | Key                   | Value                                     |
      | nodeAggregateId       | "nody-mc-nodeface"                        |
      | nodeTypeName          | "Neos.ContentRepository.Testing:Document" |
      | parentNodeAggregateId | "sir-david-nodenborough"                  |
      | nodeName              | "document"                                |
    And the graph projection is fully up to date

    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                    |
      | nodeAggregateId              | "nody-mc-nodeface"       |
      | newParentNodeAggregateId     | "lady-eleonode-rootford" |
      | relationDistributionStrategy | "scatter"                |
    Then the last command should have thrown an exception of type "NodeNameIsAlreadyCovered"

  Scenario: Try to move a node to a parent whose node type does not allow child nodes of the node's type
    Given the command CreateNodeAggregateWithNode is executed with payload:
      | Key                   | Value                                     |
      | nodeAggregateId       | "nody-mc-nodeface"                        |
      | nodeTypeName          | "Neos.ContentRepository.Testing:Document" |
      | parentNodeAggregateId | "lady-eleonode-rootford"                  |
      | nodeName              | "other-document"                          |
    And the graph projection is fully up to date

    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value               |
      | nodeAggregateId              | "nody-mc-nodeface"  |
      | newParentNodeAggregateId     | "nodewyn-tetherton" |
      | relationDistributionStrategy | "scatter"           |
    Then the last command should have thrown an exception of type "NodeConstraintException"

  Scenario: Try to move a node to a parent whose parent's node type does not allow grand child nodes of the node's type
    Given the command CreateNodeAggregateWithNode is executed with payload:
      | Key                   | Value                                    |
      | nodeAggregateId       | "nody-mc-nodeface"                       |
      | nodeTypeName          | "Neos.ContentRepository.Testing:Content" |
      | parentNodeAggregateId | "lady-eleonode-rootford"                 |
      | nodeName              | "content"                                |
    And the graph projection is fully up to date
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value               |
      | nodeAggregateId              | "nody-mc-nodeface"  |
      | newParentNodeAggregateId     | "nodewyn-tetherton" |
      | relationDistributionStrategy | "scatter"           |
    Then the last command should have thrown an exception of type "NodeConstraintException"

  Scenario: Try to move existing node to a non-existing succeeding sibling
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                                 | Value                    |
      | nodeAggregateId                     | "sir-david-nodenborough" |
      | newSucceedingSiblingNodeAggregateId | "i-do-not-exist"         |
      | relationDistributionStrategy        | "scatter"                |
    Then the last command should have thrown an exception of type "NodeAggregateCurrentlyDoesNotExist"

  Scenario: Try to move existing node to a new succeeding sibling whose parent does not allow nodes of its type
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                                 | Value                    |
      | nodeAggregateId                     | "sir-nodeward-nodington-iii" |
      | newSucceedingSiblingNodeAggregateId | "nodimus-prime"       |
      | relationDistributionStrategy        | "scatter"                |
    Then the last command should have thrown an exception of type "NodeConstraintException"

  Scenario: Try to move existing node to a new succeeding sibling whose grandparent does not allow nodes of its type below the sibling's name
    Given the command CreateNodeAggregateWithNode is executed with payload:
      | Key                   | Value                                           |
      | nodeAggregateId       | "nody-mc-nodeface"                              |
      | nodeTypeName          | "Neos.ContentRepository.Testing:Content" |
      | parentNodeAggregateId | "sir-nodeward-nodington-iii"                             |
    And the graph projection is fully up to date
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                                 | Value                    |
      | nodeAggregateId                     | "sir-nodeward-nodington-iii" |
      | newSucceedingSiblingNodeAggregateId | "nodimus-prime"       |
      | relationDistributionStrategy        | "scatter"                |
    Then the last command should have thrown an exception of type "NodeConstraintException"

  Scenario: Try to move existing node to a non-existing preceding sibling
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                                | Value                    |
      | nodeAggregateId                    | "sir-david-nodenborough" |
      | newPrecedingSiblingNodeAggregateId | "i-do-not-exist"         |
      | relationDistributionStrategy       | "scatter"                |
    Then the last command should have thrown an exception of type "NodeAggregateCurrentlyDoesNotExist"

  Scenario: Try to move existing node to a new preceding sibling whose parent does not allow nodes of the former's type
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                                | Value                    |
      | nodeAggregateId                    | "sir-nodeward-nodington-iii" |
      | newPrecedingSiblingNodeAggregateId | "nodimus-prime"       |
      | relationDistributionStrategy       | "scatter"                |
    Then the last command should have thrown an exception of type "NodeConstraintException"

  Scenario: Try to move existing node to a new preceding sibling whose grandparent does not allow nodes of its type below the sibling's name
    Given the command CreateNodeAggregateWithNode is executed with payload:
      | Key                   | Value                                           |
      | nodeAggregateId       | "nody-mc-nodeface"                              |
      | nodeTypeName          | "Neos.ContentRepository.Testing:Content" |
      | parentNodeAggregateId | "sir-nodeward-nodington-iii"                             |
    And the graph projection is fully up to date
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                                 | Value                    |
      | nodeAggregateId                     | "sir-nodeward-nodington-iii" |
      | newPrecedingSiblingNodeAggregateId | "nodimus-prime"       |
      | relationDistributionStrategy        | "scatter"                |
    Then the last command should have thrown an exception of type "NodeConstraintException"

  Scenario: Try to move a node to one of its children
    When the command MoveNodeAggregate is executed with payload and exceptions are caught:
      | Key                          | Value                    |
      | nodeAggregateId              | "sir-david-nodenborough" |
      | newParentNodeAggregateId     | "nodewyn-tetherton"      |
      | relationDistributionStrategy | "scatter"                |
    Then the last command should have thrown an exception of type "NodeAggregateIsDescendant"
