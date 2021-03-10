<?php
declare(strict_types=1);

namespace Neos\ContentRepository\Intermediary\Domain\Feature;

/*
 * This file is part of the Neos.ContentRepository.Api package.
 *
 * (c) Contributors of the Neos Project - www.neos.io
 *
 * This package is Open Source Software. For the full copyright and license
 * information, please view the LICENSE file which was distributed with this
 * source code.
 */

use Neos\ContentRepository\Domain\Model\NodeType;
use Neos\ContentRepository\Domain\NodeAggregate\NodeName;
use Neos\ContentRepository\Domain\NodeType\NodeTypeName;
use Neos\EventSourcedContentRepository\Domain\Projection\Content\NodeInterface;

/**
 * The feature trait implementing the node metadata interface based on a node
 */
trait NodeMetadata
{
    private NodeInterface $node;

    /**
     * Whether or not this node is the root of the graph, i.e. has no parent node
     */
    public function isRoot(): bool
    {
        return $this->node->isRoot();
    }

    /**
     * Whether or not this node is tethered to its parent, fka auto created child node
     */
    public function isTethered(): bool
    {
        return $this->node->isTethered();
    }

    public function getNodeTypeName(): NodeTypeName
    {
        return $this->node->getNodeTypeName();
    }

    public function getNodeType(): NodeType
    {
        return $this->node->getNodeType();
    }

    public function getNodeName(): ?NodeName
    {
        return $this->node->getNodeName();
    }

    /**
     * Returns the node label as generated by the configured node label generator
     */
    public function getLabel(): string
    {
        return $this->node->getLabel();
    }
}
